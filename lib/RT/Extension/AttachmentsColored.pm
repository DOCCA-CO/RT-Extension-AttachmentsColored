package RT::Extension::AttachmentsColored;

our $VERSION = '0.1';

RT->AddStyleSheets('AttachmentsColored.css');
RT->AddStyleSheets('select2.min.css');
RT->AddStyleSheets('dataTables.bootstrap4.min.css');
RT->AddStyleSheets('buttons.bootstrap4.min.css');
RT->AddStyleSheets('select.dataTables.min.css');

our %langMap = (
        'hu' => '//cdn.datatables.net/plug-ins/1.10.18/i18n/Hungarian.json'
    );

1;
__END__

=head1 NAME

RT::Extension::AttachmentsColored - 

=head1 DESCRIPTION

tabbed ticket header

=head1 INSTALLATION AND CONFIGURATION

1. Enable the Extension in the SiteConfig, eg.:
    Set(@Plugins, qw(RT::Extension::xyz RT::Extension::AttachmentsColored));

2. Configure Extension
insert this into siteconfig:
TODO 

=head1 AUTHOR

bekeny balint & akos torok  C<< <docca@rt.docca.hu> >>

=head1 LICENCE AND COPYRIGHT

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

