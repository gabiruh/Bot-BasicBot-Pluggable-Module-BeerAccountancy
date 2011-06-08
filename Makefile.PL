use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME          => 'Bot::BasicBot::Pluggable::Module::BeerAccountancy',
  AUTHOR        => q{Gabriel A. Santana <gabiruh@gmail.com>},
  VERSION_FROM  => 'lib/Bot/BasicBot/Pluggable/Module/BeerAccountancy.pm',
  ABSTRACT_FROM => 'lib/Bot/BasicBot/Pluggable/Module/BeerAccountancy.pm',
  ( $ExtUtils::MakeMaker::VERSION >= 6.3002
    ? ( 'LICENSE' => 'perl' )
    : () ),
  PL_FILES  => {},
  PREREQ_PM => {
    'Test::More'                       => 0,
    'Moose'                            => 0,
    'MooseX::NonMoose'                 => 0,
    'Graph'                            => 0,
    'DateTime'                         => 0,
    'Bot::BasicBot::Pluggable::Module' => 0
  },
  dist => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
  clean => { FILES => 'Bot-BasicBot-Pluggable-Module-BeerAccountancy-*' },
);
