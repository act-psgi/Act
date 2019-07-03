package Act::News;
use strict;
use Act::Config;
use Act::Data;
use Act::Object;
use base qw( Act::Object );

# class data used by Act::Object
our $table       = 'news';
our $primary_key = 'news_id';

our %sql_stub    = (
    select => "n.*",
    from   => "news n",
);
our %sql_mapping = (
    # standard stuff
    map( { ($_, "(n.$_=?)") }
         qw( news_id conf_id user_id datetime published ) )
);
our %sql_opts    = ( 'order by' => 'datetime desc' );

sub title { $_[0]{title} }
sub text  { $_[0]{text}  }

sub items
{
    my $self = shift;
    return $self->{items} if exists $self->{items};

    # fill the cache if necessary
    $self->{items} = Act::Data::fetch_news($self->news_id);
    return $self->{items};
}

sub content {
    my $self = shift;
    my $text = ref $self ? $self->text : shift;
    join( "\n", map "<p>$_</p>", split /(?:\r?\n){2,}/, $text)
}

sub create {
    my ($class, %args) = @_;
    $class = ref $class || $class;
    $class->init();

    my $items = delete $args{items};
    my $news = $class->SUPER::create(%args);
    
    if ($news && $items) {
        $news->_update_items($items);
    }
    $Request{dbh}->commit;
    return $news;
}
sub update {
    my ($self, %args) = @_;
    my $items = delete $args{items};
    
    $self->SUPER::update(%args) if %args;
    $self->_update_items($items);
    $Request{dbh}->commit;
}
sub delete {
    my ($self, %args) = @_;

    $self->_update_items( {} );
    $self->SUPER::delete(%args);
    $Request{dbh}->commit;
}
sub _update_items
{
    my ($self, $items) = @_;
    Act::Data::update_news($self->news_id,$items);
}
=head1 NAME

Act::News - An Act object representing a news item.

=head1 DESCRIPTION

This is a standard Act::Object class. See Act::Object for details.

=cut

1;
