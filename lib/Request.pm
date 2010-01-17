package Norma::Request;

use Moose;

use Norma::Request::Resource;
use Norma::Request::Dispatcher;

has 'dispatcher' => (is => 'rw');
has 'resource'   => (is => 'rw');

has 'application_url_path_prefix' => (is => 'rw');

sub BUILD {
	my ($self, $args) = @_;

	$self->{resource} = Norma::Request::Resource->new(
		application_namespace => $args->{application_namespace},
		url_path => $args->{url_path},
		url_path_prefix => $self->application_url_path_prefix,
		component_prefix => $args->{component_prefix},
	);

	$self->{dispatcher} = Norma::Request::Dispatcher->new(
		resource => $self->resource,
	);
}

sub dispatch {
	my ($self) = @_;

	$self->dispatcher->dispatch;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head NAME

Norma::Request - Map and dispatch web requests under Norma

=head1 SYNOPSIS

my $norma = Norma::Request->new(
	url_path => '/recipes/23/comments/309'
	application_namespace => 'My::App',
);

$norma->dispatch;


