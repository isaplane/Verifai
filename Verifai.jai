build_test_workspace :: (base_options: Build_Options, test_dir: string, loc := #caller_location)
{
    w := compiler_create_workspace("tests_workspace");
    assert(w > 0, "Bad workspace.\n");

    options := base_options;
    options.output_type = .EXECUTABLE;
    set_build_options(options, w);

    init_string_builder(*builder);
    test_files := find_test_files(test_dir);

    compiler_begin_intercept(w);
    for test_files add_build_file(it, w, loc);

    add_build_string(BUILD_STRING, w);
    add_test_file_string(w, test_files);

    message_loop();

    compiler_end_intercept(w);
}

print_test_info :: (files: [] string, num_tests: int)
{
    print("Found % files with % tests.\n\n", files.count, num_tests);
    print("Included files:\n");
    for files print("    - %\n", it);
}

print_test_output :: (test: Test_Case)
{

}

run_tests :: (tests: [] Test_Case)
{
    num_failed := 0;

    t_start := current_time_monotonic();

    for tests
    {
        it.proc();
        print_test_output(it);
    }

    t_stop := current_time_monotonic();

    elapsed_time := to_milliseconds(t_stop - t_start, false);

    print("Ran % tests in % ms.\n", tests.count, elapsed_time);
}

Test_Case :: struct
{
    name: string;
    proc: #type ();

    msgBuffer: = String_Builder.{ allocator = temp };
    failedExpr: string;
    failedLocation: Source_Code_Location;
    failed: bool = false;
}

#scope_module

builder: String_Builder;
tests_written: bool;

find_test_files :: (test_dir: string) -> [] string
{
    files := file_list(test_dir);
    assert(files.count > 0, "Couldn't find files in test directory.");

    return files;
}

add_test_file_string :: (w: Workspace, test_files: [] string)
{
    print_to_builder(*builder, "test_files: [%] string = \n", test_files.count);
    print_to_builder(*builder, ".[\n");
    for test_files
    {
        print_to_builder(*builder, "    \"%\",\n", it);
    }
    print_to_builder(*builder, "];\n");

    add_build_string(builder_to_string(*builder), w);
    free_buffers(*builder);
}

add_test_string :: (w: Workspace, tests: [..] *Code_Procedure_Header)
{
    print_to_builder(*builder, "tests: [%] Verifai.Test_Case = \n", tests.count);
    print_to_builder(*builder, ".[\n");
    for tests
    {
        print_to_builder(*builder, "    .{name = \"%\", proc = %},\n", it.name, it.name);
    }
    print_to_builder(*builder, "];\n");

    add_build_string(builder_to_string(*builder), w);
    free_buffers(*builder);
}

message_loop :: ()
{
    test_headers: [..] *Code_Procedure_Header;

    while true
    {
        message := compiler_wait_for_message();
        if message.kind ==
        {
            case .TYPECHECKED;
                typechecked := cast(*Message_Typechecked) message;

                for tc: typechecked.procedure_headers
                {
                    proc := tc.expression;
                    if has_note(proc, "Test")
                        array_add(*test_headers, proc);
                }

            case .PHASE;
                phase := cast(*Message_Phase) message;
                if phase.phase ==
                {
                    case .TYPECHECKED_ALL_WE_CAN;
                        if tests_written continue;

                        add_test_string(message.workspace, test_headers);
                        tests_written = true;
                }

            case .COMPLETE;
                break;
        }
    }
}

handle_message :: (message: *Message)
{
}

has_note :: (header: *Code_Procedure_Header, note: string) -> bool
{
    for header.notes
        if it.text == note return true;
    return false;
}

BUILD_STRING :: #string
HERE
#import "Basic";

main :: ()
{
    Verifai.print_test_info(test_files, tests.count);
    Verifai.run_tests(tests);
}
HERE

#import "Basic";
#import "Compiler";
#import "File_Utilities";
#import "Print_Color";
