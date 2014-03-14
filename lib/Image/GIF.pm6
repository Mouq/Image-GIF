use X::Image::GIF;
class Image::GIF::Block {
    #| local color table
    has Str @.color-table is rw;
    has $.disposal-method is rw;
    has $.user-input is rw;
    has $.delay is rw;
    has $.transparency-idx is rw;
    has $.top is rw;
    has $.left is rw;
    has $.width is rw;
    has $.height is rw;
}

class Image::GIF {
    has $.ver is rw;
    has $.width is rw;
    has $.height is rw;
    #| global color table (should be sorted when printed(?))
    has Str @.color-table is rw;
    has $!color-resolution;
    has $.bg-color-idx is rw;
    has $.px-aspect-ratio is rw;
    has Image::GIF::Block @.data;

    method aspect-ratio { ($.px-aspect-ration + 15) / 64 }

    our proto decode-gif (|) returns Image::GIF is export {*}
    multi decode-gif(IO::Handle $f) {
        decode-gif $f.slurp(:bin); # XXX
    }
    multi decode-gif(Buf $b) {
        Image::GIF.new!decode-gif($b)
    }

    method !decode-gif (Buf $b --> Image::GIF) {
        my $pos = -1;
        my sub term:<get> () { $b[++$pos] }
        my sub term:<sub-block> () { my$n=get; get xx $n; $n }
        my &bad-gif = ->$p?{
            X::Image::GIF::Malformed.new(:pos($p // $pos)).fail;
        }

        # Header
        chrs(get xx 3) eq "GIF" or bad-gif;
        ($!ver = chrs get xx 3) eq "87a"|"89a"
            or X::Image::GIF::Unknown.new(:version($!ver)).throw;

        # Logical Screen Descriptor
        $!width  = get + get+<8;
        $!height = get + get+<8;
        my $gct-exists; # Do we have a global color table?
        my $gct-size;   # How big is it?
        do {
            # <Packed Fields>
            my @packed = get.base(2).fmt("%08d").comb;
            $gct-exists = @packed[0];
            $!color-resolution = :2(@packed[1..3].join);
            # Skip @packed[4] -- we don't need to know
            $gct-size = 2**(:2(@packed[5..7].join) + 1);
        }
        $!bg-color-idx = get;
        $!px-aspect-ratio = get;

        # Global Color Table
        if $gct-exists {
            @!color-table.push: (get*16**2 + get*16 + get).fmt("%06X")
                for ^$gct-size;
        }

        # Labeled blocks
        my $gce = False; # Was the last block a Graphic Control Extention
        loop { given get {
            when $.ver ge "89a" && 0x21 { # Extention
                given get {
                    when 0xFE { # Comment
                        repeat {} while sub-block;
                    }
                    when 0xFF { # Application
                        sub-block;
                        repeat {} while sub-block;
                    }
                    when 0x01 { # Plain Text, no point supporting
                        sub-block;
                        repeat {} while sub-block;
                    }
                    when 0xF9 { # Graphic Control
                        $gce = True;
                        @!data[+*] //= Image::GIF::Block.new;
                        get;
                        my @packed = get.base(2).fmt("%08d").comb;
                        @!data[*-1].disposal-method = :2(@packed[3..5].join);
                        @!data[*-1].user-input = @packed[6];
                        @!data[*-1].delay = get+<8 + get;
                        @!data[*-1].transparency-idx = @packed[7] * get;
                        get != 0 and bad-gif;
                    }
                }
            }
            when 0x2C { # Image Descriptor
                @!data[$gce ?? *-1 !! +*] //= Image::GIF::Block.new;
                @!data[*-1].left   = get + get+<8;
                @!data[*-1].top    = get + get+<8;
                @!data[*-1].width  = get + get+<8;
                @!data[*-1].height = get + get+<8;
                my @packed = get.base(2).fmt("%08d").comb;
                # Local Color Table
                if @packed[0] {
                    @!data[*-1].color-table.push: (get*16**2 + get*16 + get).fmt("%06X")
                        for ^2**(:2(@packed[5..7].join)+1);
                }
                my $init-code-size = get;
                my %enc;
                my @bytes = gather while get -> $_ {
                    for ^$_ {
                        get.base(2).fmt("%08d").comb.».take
                    }
                }
                my $code-size = $init-code-size;
                #say @bytes.join.comb: rx{ ^[
                #    || <{(2**$code-size).base(2)}> {$code-size = $init-code-size}
                #    || <{(2**$code-size+1).base(2)}> {last}
                #    || <{(2**$code-size+2).base(2)}> {}
                #    || <{".**{$code-size+1}"}>
                #]};
                #say $code-size;
                $gce = False;
            }
            when 0x3B { # Trailer
                last
            }
            default { note "$pos -- $b[$pos]"; bad-gif }
        }}

        self;
    }

}
