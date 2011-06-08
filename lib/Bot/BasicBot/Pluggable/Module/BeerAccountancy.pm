package Bot::BasicBot::Pluggable::Module::BeerAccountancy;

use utf8;

use Moose;
use MooseX::NonMoose;
extends 'Bot::BasicBot::Pluggable::Module';

use Graph::Directed;
use DateTime;

=head1 NAME

Bot::BasicBot::Pluggable::Module::BeerAccountancy

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

A module to keep track of beers owed by a nickname

=cut

has beers => (
  is         => 'ro',
  isa        => 'Object',
  lazy_build => 1,
);

has _dispatch_table => (
  is         => 'ro',
  traits     => ['Hash'],
  isa        => 'HashRef',
  lazy_build => 1,
  handles    => { _message_patterns => 'keys', _match => 'get' }

);

sub _build__dispatch_table {
  my ($self) = @_;
  my $nick   = '([\w\d_]+)';
  my $reason = '(?:\s*#\s*(.*))?';

  # O código a seguir é de uma condescendência sem precedentes aos
  # assassinos da regência verbal e à norma culta. Espero que a vida
  # real não seja tão complacente assim.
  #
  # Que a terra *não* lhes seja leve.

  my $to = '(?:ao?|pa?r[ao])';

  return {
    qr/devo uma cerveja $to $nick$reason/ =>
      sub { $self->owes_beer( $_[0], $_[0]->{who}, $1, $2 ) },
    qr/paguei uma cerveja $to $nick$reason/ =>
      sub { $self->pays_beer( $_[0], $_[0]->{who}, $1 ) },
    qr/quantas cervejas eu devo\s*\?/ =>
      sub { $self->to_whom_owes( $_[0], $_[0]->{who} ) },
    qr/quantas cervejas(?: eu)? devo $to $nick\s*\?/ =>
      sub { $self->how_many_beers_owed_to( $_[0], $_[0]->{who}, $1 ) },
    qr/quantas cervejas $nick (?:me deve|deve a mim)\s*\?/ =>
      sub { $self->how_many_beers_owed_to( $_[0], $1, $_[0]->{who} ) },
    qr/quantas cervejas (?:me devem|devem a mim)\s*\?/ =>
      sub { $self->who_owes_to( $_[0], $_[0]->{who} ) },
    qr/quantas cervejas $nick deve $to $nick\s*\?/ =>
      sub { $self->how_many_beers_owed_to( $_[0], $1, $2 ) },
    qr/quantas cervejas $nick deve\s*\?/ =>
      sub { $self->to_whom_owes( $_[0], $1 ) },
    qr/quantas cervejas devem $to $nick\s*\?/ =>
      sub { $self->who_owes_to( $_[0], $1 ) },
  };

}

sub _store_beers {
  my ($self) = @_;
  $self->set( '__beers', $self->beers );
}

sub init {
  my ($self) = @_;
  $self->config( { beer_accepted_command_message => 'ok!' } );
}

sub _dispatch {
  my ( $self, $m ) = @_;
  my $body = $m->{body};

  for my $re ( $self->_message_patterns ) {
    return 1 if $body =~ $re and $self->_match($re)->($m);
  }
  return;
}

sub fallback {
  my ( $self, $message ) = @_;
  return unless $message->{address};
  return 1 if $self->_dispatch($message);
  return;
}

sub _build_beers {
  my ($self) = @_;
  $self->set( '__beers', Graph::Directed->new() ) unless $self->get('__beers');
  return $self->get('__beers');
}

# $fulano deve uma cerveja a $cicrano.
sub owes_beer {
  my ( $self, $m, $debtor, $creditor, $reason ) = @_;

  if ( $debtor eq $creditor ) {
    $self->reply( $m, 'tsc... lá vai um pinguço beber sozinho...' );
    return 0;
  }

  my $payroll = $self->beers->get_edge_weight( $debtor => $creditor ) || [];
  push @$payroll, { reason => $reason, timestamp => time };
  $self->beers->add_weighted_edge( $debtor => $creditor => $payroll );
  $self->reply( $m, 'ok!' );
  return 1;
}

# $fulano pagou uma cerveja a $cicrano.
sub pays_beer {
  my ( $self, $m, $debtor, $creditor ) = @_;

  if ( $debtor eq $creditor ) {
    $self->reply( $m, 'aham, Cláudia, senta lá.' );
    return 0;
  }

  my $payroll = $self->beers->get_edge_weight( $debtor => $creditor );

  if ( !$payroll ) {
    $self->reply( $m, 'pff.. é uma anta, nem devia.' );
    return 0;
  }

  shift @$payroll;
  my $beers_left = scalar @$payroll;

  $self->reply( $m,
    'ok!' . ( $beers_left ? " Ainda falta(m) $beers_left." : '' ) );

  $self->beers->delete_edge_weight( $debtor => $creditor ) if $beers_left == 0;
  return 1;
}

# Não esquecer de anotar as contas. Afinal, tamo aqui pra lembrar, né?
after [qw(owes_beer pays_beer)] => sub { shift->_store_beers };

# Quantas cervejas $fulano deve a $cicrano?
sub how_many_beers_owed_to {
  my ( $self, $m, $debtor, $creditor ) = @_;

  if ( my $debts = $self->beers->get_edge_weight( $debtor => $creditor ) ) {
    my $n       = scalar @$debts;
    my $reasons = $self->_build_reasons($debts);
    my $body    = "$n: $reasons";
    $self->reply( $m, $body );
    return 1;
  }

  $self->reply( $m, '0' );
  return 0;
}

# Quem deve a $fulano?
sub who_owes_to {
  my ( $self, $m, $creditor ) = @_;
  if ( my $debts =
    $self->_build_debts( [ $self->beers->edges_to($creditor) ] ) )
  {
    return 1 if $self->_reply_payroll( $debts, $m );
  }
  $self->reply( $m, '0' );
  return 0;
}

# A quem $fulano deve?
sub to_whom_owes {
  my ( $self, $m, $debtor ) = @_;
  if ( my $debts =
    $self->_build_debts( [ $self->beers->edges_from($debtor) ] ) )
  {
    return 1
      if $self->_reply_payroll(
      [ map { [ [ reverse @{ $_->[0] } ] => $_->[1] ] } @$debts ], $m );
  }
  $self->reply( $m, '0' );
  return 0;
}

# Montando e respondendo a "folha de pagamento"
sub _reply_payroll {
  my ( $self, $payroll, $m ) = @_;
  return 0 unless scalar @$payroll;

  my $body;
  foreach my $debt (@$payroll) {
    my ( $participants, $reasons )  = @$debt;
    my ( $debtor,       $creditor ) = @$participants;
    my $n           = scalar @$reasons;
    my $reasons_str = $self->_build_reasons($reasons);
    $body .= "$debtor ($n): $reasons_str; ";
  }

  $self->reply( $m, $body );
  return 1;
}

# Montando a estrutura que define as dívidas.
sub _build_debts {
  my ( $self, $payroll ) = @_;
  return 0 unless scalar @$payroll;

  my @debts;
  foreach my $debt (@$payroll) {
    my ( $debtor, $creditor ) = @$debt;
    push @debts,
      [ [ $debtor => $creditor ] =>
        $self->beers->get_edge_weight( $debtor => $creditor ) ];
  }

  return 0 unless scalar @debts;
  return \@debts;
}

# Montando os motivos das dívidas.
sub _build_reasons {
  my ( $self, $reasons ) = @_;
  return join(
    ', ',
    map {
      sprintf(
        '"%s" [%s]',
        $_->{reason} || '(sem motivo)',
        DateTime->from_epoch(
          epoch     => $_->{timestamp},
          time_zone => 'local'
        )
        )
      } @$reasons
  );
}

=head1 AUTHOR

Gabriel A. Santana, C<< <gabiruh at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-bot-basicbot-pluggable-module-beeraccountancy at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Bot-BasicBot-Pluggable-Module-BeerAccountancy>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Bot::BasicBot::Pluggable::Module::BeerAccountancy


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Bot-BasicBot-Pluggable-Module-BeerAccountancy>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Bot-BasicBot-Pluggable-Module-BeerAccountancy>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Bot-BasicBot-Pluggable-Module-BeerAccountancy>

=item * Search CPAN

L<http://search.cpan.org/dist/Bot-BasicBot-Pluggable-Module-BeerAccountancy/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Gabriel A. Santana.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Bot::BasicBot::Pluggable::Module::BeerAccountancy
