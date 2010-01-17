package Norma::Request::Dispatcher;

use Moose;

has 'resource' => (is => 'ro');
has 'mason'    => (is => 'ro');

sub BUILD {
	my ($self, $args) = @_;

	unless ($self->mason) {

		if (eval '$HTML::Mason::Commands::m') {
			$self->{mason} = $HTML::Mason::Commands::m;
		} else {
			die "we need a mason object";
		}
	}
}

no Moose;

sub dispatch {

	my ($self) = @_;

	my $resource = $self->resource;

	if ($resource->action =~ /^(view|edit|list|add|delete)$/) {
		my $class = $resource->class;
		die "invalid class: $class" unless $class =~ m/^[\w:]+$/;
		eval "require $class" || die "couldn't require $class";

		my $component_args;

		if ($resource->action =~ /^(view|edit|delete)$/) {
			$component_args->{item} = $resource->class->load(
				$class->_table->{key_field_names}->[0] => $resource->item_ids->{ $resource->class }
			);
		} elsif ($resource->action =~ /^list$/) {
			$component_args->{class} = $resource->class;
			#$component_args->{collection} = $resource->class->collect;

		} elsif ($resource->action =~ /^add$/) {
			$component_args->{class} = $resource->class;
		}

		if ($self->mason->comp_exists($resource->component)) {
			$HTML::Mason::Commands::r->log_error("subrequest " . $resource->component);
			my $request = $self->mason->make_subrequest(comp => $resource->component, args => [ parent => $self->mason, %{ $self->mason->request_args }, %$component_args ]);
			$request->exec;
		} else {
			$HTML::Mason::Commands::r->log_error("comp " . $resource->component);
			$self->mason->comp("/norma/". $resource->action, %$component_args);
		}
	}
}

__PACKAGE__->meta->make_immutable;
