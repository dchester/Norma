package Norma::View::Configuration;

use Moose;

has 'callbacks' => (is => 'rw', isa => 'HashRef', default => sub{ {} });

no Moose;

sub BUILD {
	my ($self, $args) = @_;
	$self->register(%$args);
}

sub register {
	my ($self, %callbacks) = @_;

	while (my ($name, $callback) = each %callbacks) {

		unless ((ref $callback) eq 'CODE') {
			die "invalid sub ref: $callback";
		}

		$self->{callbacks}->{$name} = $callback;
	}
}

sub AUTOLOAD {
	my $self = shift;
	return unless ref $self;	

	our $AUTOLOAD;

	my ($callback_name) = $AUTOLOAD =~ /::(\w+)$/;
	my $callback = $self->callbacks->{$callback_name};

	return $callback ? &$callback(@_) : shift;
}

__PACKAGE__->meta->make_immutable;

1;
