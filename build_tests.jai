EXE_NAME :: "tests";

build :: ()
{
    w := verifai.begin_test_workspace(EXE_NAME);

    options := get_build_options(w);
    options.output_path = tprint("%/bin", #filepath);
    set_build_options(options, w);

    verifai.end_test_workspace(w);

    set_build_options_dc(.{do_output = false});
}

#run build();

#import "Basic";
#import "Compiler";
verifai :: #import,file "./verifai.jai";

