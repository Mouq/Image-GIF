use Test;
use Image::GIF;

my $flutterby = open "t/Agrias_butterfly.gif", :bin;
say decode-gif $flutterby.slurp(:bin);
# decode-gif $flutterby;
my $animated = open "t/In_circle.gif", :bin;
say decode-gif $animated.slurp(:bin);
