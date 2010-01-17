package Norma::Request::Resource;

use String::CamelCase qw(camelize decamelize);
use Lingua::EN::Inflect::Number qw(to_S to_PL);

use Moose;

has 'class'            => (is => 'ro');
has 'component'        => (is => 'ro');
has 'component_base'   => (is => 'ro');
has 'component_prefix' => (is => 'ro', default => '/');
has 'action'           => (is => 'ro');
has 'item_ids'         => (is => 'ro', isa => 'HashRef', default => sub { {} });
has 'url_path'         => (is => 'ro');
has 'url_path_base'    => (is => 'ro');
has 'url_path_prefix'  => (is => 'ro', default => '/');

has 'application_namespace' => (is => 'ro');

sub BUILD {
	my ($self, $args) = @_;
	
	#my ($path) = $self->url_path =~ m|^$self->url_path_prefix/(.+)|;
	my @path_components = split m|/|, $self->url_path;

	my @class_components;
	my $running_class;

	for my $c (@path_components) {
		if ($c =~ /^\d+$/) {
			# $self->class is running 
			$self->{item_ids}->{$self->{class}} = $c;

		} elsif ($c =~ /^(view|edit|delete|add)$/) {
			$self->{action} = $c;	

		} else {
			push @class_components, $c; 
		}
		$self->{class} = join '::', 
			$self->application_namespace, 
			map { camelize to_S $_ } @class_components;
	}
	$self->{action} ||= $self->item_ids->{ $self->class } ? 'view' : 'list';

	$self->{component_base} = join '/', '', map { to_S $_ } @class_components;

	$self->{component} = join '/', $self->{component_prefix}, $self->{component_base}, $self->{action};
	$self->{component} =~ s|/+|/|g;

	$self->{url_path_base} = join '/', @class_components;
} 

no Moose;
__PACKAGE__->meta->make_immutable;
