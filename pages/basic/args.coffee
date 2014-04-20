code = """\
// print number of args
<<< "number of arguments:", me.args() >>>;

// print each
for( int i; i < me.args(); i++ )
{
    <<< "   ", me.arg(i) >>>;
}
"""
