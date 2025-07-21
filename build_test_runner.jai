TEST_DIR :: "tests";

build :: ()
{
    set_build_options_dc(.{do_output = false});

    set_working_directory(#filepath);
    options := get_build_options();

    w := Verifai.build_and_run_tests(options, TEST_DIR);
}

#run build();

#import "Basic";
#import "Compiler";
Verifai :: #import "Verifai";
