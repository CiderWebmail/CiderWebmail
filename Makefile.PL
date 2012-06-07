use inc::Module::Install;

name 'CiderWebmail';
all_from 'lib/CiderWebmail.pm';

requires 'parent';
requires 'Moose';
requires 'MooseX::Role::WithOverloading' => '0.09';

requires 'Catalyst::Runtime' => '5.80030';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Unicode';
requires 'Catalyst::Plugin::StackTrace';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Plugin::Session::Store::FastMmap';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Authentication::Credential::HTTP';
requires 'Catalyst::Model::DBIC::Schema' => '0.41';
requires 'Catalyst::ScriptRunner';

requires 'Catalyst::Action::RenderView' => '0.16';
requires 'YAML'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
requires 'YAML::XS';

requires 'Catalyst::View::Petal';
requires 'Petal::Utils';

requires 'DateTime';
requires 'DateTime::Format::Mail';

requires 'MIME::WordDecoder';
requires 'MIME::Tools';
requires 'MIME::Parser';
requires 'MIME::Lite';
requires 'MIME::Words';

requires 'Email::Simple';
requires 'Email::Valid';
requires 'Email::Address';
requires 'Regexp::Common::Email::Address';
requires 'Regexp::Common::URI';

requires 'Text::Iconv';
requires 'Text::Autoformat';

requires 'IO::Socket::SSL';

requires 'Parse::RecDescent' => '1.967009'; #https://rt.cpan.org/Public/Bug/Display.html?id=76118
requires 'Mail::IMAPClient' => '3.31';

requires 'Clone';
requires 'HTML::Scrubber';
requires 'HTML::Tidy';
requires 'URI::QueryParam';

requires 'Locale::Maketext::Gettext';

requires 'List::MoreUtils';

requires 'Data::ICal';
requires 'DateTime::Format::ISO8601';

requires 'Crypt::Util';
requires 'Crypt::CBC';

requires 'Crypt::Rijndael';
requires 'Crypt::Random::Source';
requires 'MIME::Base64::URLSafe';

requires 'FCGI';
requires 'FCGI::ProcManager';


#catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
