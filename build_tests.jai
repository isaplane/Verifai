EXE_NAME :: "tests";

build :: ()
{
    set_build_options_dc(.{do_output = false});

    set_working_directory(#filepath);
    options := get_build_options();
    options.output_path = "bin";
    options.output_executable_name = EXE_NAME;

    w := Verifai.build_test_workspace(options, "tests");
}

#run build();

#import "Basic";
#import "Compiler";
Verifai :: #import "Verifai";
