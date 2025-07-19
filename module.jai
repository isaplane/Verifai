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
    for files print(prepend_indents(tprint("- %\n", it), 1));
}

print_test_output :: (test: Test_Case, indent_count: int)
{
    if !test.has_test
    {
        print_color(prepend_indents("skip: ", indent_count), color = .YELLOW); 
        print("%\n", test.name);
        print(prepend_indents("Missing a test expression!\n", indent_count + 1));
        return;
    }

    if test.failed
    {
        print_color(prepend_indents("fail: ", indent_count), color = .RED); 
        print("%\n", test.name);
        print(prepend_indents(tprint("Failing expression (line %): %\n", test.location.line_number, test.failed_expr), indent_count + 1));
        return;
    }

    print_color(prepend_indents("pass: ", indent_count), color = .GREEN);
    print("%\n", test.name);
}

run_tests :: (tests: [] Test_Case)
{
    compare_test_cases :: (a: Test_Case, b: Test_Case) -> int
    {
        a_loc := a.location.fully_pathed_filename;
        b_loc := b.location.fully_pathed_filename;

        return compare_strings(a_loc, b_loc);
    }

    bubble_sort(tests, compare_test_cases);

    num_failed := 0;
    indent_count := 1;
    current_file := "";

    t_start := current_time_monotonic();

    print("\n");
    for tests
    {
        new_context := context;
        new_context.test_case = *it;

        push_context new_context
        {
            it.proc();
        }

        path := it.location.fully_pathed_filename;
        if path != current_file
        {
            print("\n%:\n", path);
            current_file = path;
        }

        print_test_output(it, indent_count);
    }

    t_stop := current_time_monotonic();

    elapsed_time := to_milliseconds(t_stop - t_start, false);

    print("\nRan % tests in % ms.\n", tests.count, elapsed_time);
    print_color("% passed, ", tests.count - num_failed, color = .GREEN);
    print_color("% failed.\n", num_failed, color = .RED);
}

is_true :: ($expr: Code, $call := #caller_code) #expand
{
    value := #insert expr;
    value_is_true(value, call);
}

is_false :: ($expr: Code, $call := #caller_code) #expand
{
    value := !(#insert expr);
    value_is_true(value, call);
}

// are_equal :: ($actual: Code, $expected: Code, $call := #caller_code) #expand
// {
//     actual_value := #insert actual;
//     expected_value := #insert expected;
//
//     value := actual_value == expected_value;
//     value_is_true(value, call);
// }
//
// are_not_equal :: ($actual: Code, $expected: Code, $call := #caller_code) #expand
// {
//     actual_value := #insert actual;
//     expected_value := #insert expected;
//
//     value := actual_value != expected_value;
//     value_is_true(value, call);
// }

is_null :: ($expr: Code, $call := #caller_code) #expand
{
    value := (#insert expr) == null;
    value_is_true(value, call);
}

is_not_null :: ($expr: Code, $call := #caller_code) #expand
{
    value := (#insert expr) != null;
    value_is_true(value, call);
}

Test_Case :: struct
{
    name: string;
    proc: #type ();

    msg_buffer: = String_Builder.{ allocator = temp };
    location: Source_Code_Location;
    has_test := false;

    failed_expr: string;
    failed := false;
}
#add_context test_case: *Test_Case;

#scope_module

value_is_true :: (value: bool, $call := #caller_code)
{
    using context.test_case;

    has_test = true;

    if !value 
    {
        failed_expr = #run get_expression(call);
        failed = true;
    }
}

builder: String_Builder;

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
        print_to_builder(*builder, "    .{name = \"%\", proc = %, location = .{fully_pathed_filename = \"%\", line_number = %, character_number = %}},\n", 
            it.name, it.name, it.enclosing_load.fully_pathed_filename, it.l0, it.c0);
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
                        if test_headers.count == 0 continue;

                        add_test_string(message.workspace, test_headers);
                        array_reset(*test_headers);
                }

            case .COMPLETE;
                break;
        }
    }
}

has_note :: (header: *Code_Procedure_Header, note: string) -> bool
{
    for header.notes
        if it.text == note return true;
    return false;
}

get_expression :: (call := #caller_code) -> string
{
    root := compiler_get_nodes(call);
    builder: String_Builder;
    print_expression(*builder, root);
    return builder_to_string(*builder);
}

prepend_indents :: (str: string, num_indents: int) -> string
{
    builder: String_Builder;

    for 0..num_indents-1 print_to_builder(*builder, "\t");
    print_to_builder(*builder, str);
    return builder_to_string(*builder);
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
#import "Sort";
#import "Compiler";
#import "Program_Print";
#import "File_Utilities";
#import "Print_Color";
