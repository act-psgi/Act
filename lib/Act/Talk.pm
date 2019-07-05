package Act::Talk;
use Act::Config;
use Act::Data;
use Act::Object;
use base qw( Act::Object );

# class data used by Act::Object
our $table       = 'talks';
our $primary_key = 'talk_id';

our %sql_stub    = (
    select => "t.*",
    from   => "talks t",
);
our %sql_mapping = (
    title     => "(t.title~*?)",
    abstract  => "(t.abstract~*?)",
    teaser    => "(t.teaser~*?)",

    # datetime    => recherche par date ?
    # standard stuff
    map( { ($_, "(t.$_=?)") } qw<
            talk_id user_id conf_id duration room
            lightning accepted confirmed track_id
            allow_record hide_details
        >
    )
);
our %sql_opts    = ( 'order by' => 'talk_id' );

*get_talks = \&Act::Object::get_items;

sub delete {
    my ($self, %args) = @_;

    Act::Data::delete_talk_attendance($self->talk_id);

    $self->SUPER::delete(%args);
    $Request{dbh}->commit;
}

sub stars {
    my ($self, %args) = @_;
    return Act::Data::talk_stars($self->talk_id);
}

=head1 NAME

Act::Talk - An Act object representing a talk.

=head1 DESCRIPTION

This is a standard Act::Object class. See Act::Object for details.

=cut

1;

