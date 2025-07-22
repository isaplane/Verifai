build_test_executable :: (base_options: Build_Options, test_dir: string, loc := #caller_location)
{
    options := base_options;
    options.output_type = .EXECUTABLE;

    build_tests(options, test_dir, EXEC_STRING, loc);
}

build_and_run_tests :: (base_options: Build_Options, test_dir: string, loc := #caller_location)
{
    set_build_options_dc(.{do_output = false});

    build_tests(base_options, test_dir, RUN_STRING, loc);
}

print_test_info :: (files: [] string, num_tests: int)
{
    print("\nFound % files with % tests.\n\n", files.count, num_tests);
    print("Included files:\n");
    for files print(prepend_indents(tprint("- %\n", it), 1));
}

print_passed_test_output :: (test: Test, indent_count: int)
{
    print_color(prepend_indents("pass: ", indent_count), color = .GREEN);
    print("%\n", test.name);
}

print_failed_test_output :: (test: Test, indent_count: int)
{
    print_color(prepend_indents("fail: ", indent_count), color = .RED); 
    print("%\n", test.name);
    print(prepend_indents(tprint("Failing expression (line %): %\n", test.location.line_number, test.failed_expr), indent_count + 1));
}

print_skipped_test_output :: (test: Test, indent_count: int)
{
    print_color(prepend_indents("skip: ", indent_count), color = .YELLOW); 
    print("%\n", test.name);
    print(prepend_indents("Missing a test expression!\n", indent_count + 1));
}

run_tests :: (tests: [] Test)
{
    compare_test_cases :: (a: Test, b: Test) -> int
    {
        a_loc := a.location.fully_pathed_filename;
        b_loc := b.location.fully_pathed_filename;

        return compare_strings(a_loc, b_loc);
    }

    bubble_sort(tests, compare_test_cases);

    num_failed := 0;
    num_skipped := 0;
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

        if it.state ==
        {
            case .PASSED; print_passed_test_output (it, indent_count);
            case .FAILED; print_failed_test_output (it, indent_count); num_failed  += 1;
            case .UNRUN;  print_skipped_test_output(it, indent_count); num_skipped += 1;
        }
    }

    t_stop := current_time_monotonic();

    elapsed_time := to_milliseconds(t_stop - t_start, false);

    print("\nRan % tests in % ms.\n", tests.count, elapsed_time);
    print_color("% ", tests.count - num_failed - num_skipped, color = .GREEN); print("passed, ");
    print_color("% ", num_failed, color = .RED); print("failed, ");
    print_color("% ", num_skipped, color = .YELLOW); print("skipped.\n\n");
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

Test :: struct
{
    name: string;
    proc: #type () -> void;

    msg_buffer: = String_Builder.{ allocator = temp };
    location: Source_Code_Location;

    state: Test_State = .UNRUN;

    failed_expr: string;

    is_parameterized: bool;
    parameter_array_name: string;
    parameter_index: int;
}
#add_context test_case: *Test;

#scope_module

Test_State :: enum
{
    UNRUN;
    PASSED;
    FAILED;
}

Param_Array_Info :: struct
{
    name: string;
    count: int;
    element_type: Type;
}

build_tests :: (options: Build_Options, test_dir: string, build_str: string, loc: Source_Code_Location)
{
    w := compiler_create_workspace("tests_workspace");
    assert(w > 0, "Bad workspace.\n");

    set_build_options(options, w);
    compiler_begin_intercept(w);

    test_files := find_test_files(test_dir);
    for test_files add_build_file(it, w, loc);

    builder: String_Builder;
    add_build_string(build_str, w);
    add_build_string(create_test_file_string(test_files, builder), w);

    message_loop(builder);
    compiler_end_intercept(w);
}

value_is_true :: (value: bool, $call := #caller_code)
{
    using context.test_case;

    if value 
    {
        state = .PASSED;
        return;
    }

    failed_expr = #run get_expression(call);
    state = .FAILED;
    return;
}

find_test_files :: (test_dir: string) -> [] string
{
    files := file_list(test_dir);
    assert(files.count > 0, "Couldn't find files in test directory.");

    return files;
}

create_test_file_string :: (test_files: [] string, builder: String_Builder) -> string
{
    print_to_builder(*builder, "test_files: [%] string = \n", test_files.count);
    print_to_builder(*builder, ".[\n");
    for test_files
    {
        print_to_builder(*builder, "    \"%\",\n", it);
    }
    print_to_builder(*builder, "];\n");

    return builder_to_string(*builder);
}

create_test_string :: (tests: [] Test, builder: String_Builder) -> string
{
    print_to_builder(*builder, "tests: [%] Verifai.Test = \n", tests.count);
    print_to_builder(*builder, ".[\n");
    for tests
    {
        if it.is_parameterized
        {
            print_to_builder(*builder, "    .{name = \"%\", proc = () => %(%[%]), location = .%},\n", it.name, it.name, it.parameter_array_name, it.parameter_index, it.location);
            continue;
        }

        print_to_builder(*builder, "    .{name = \"%\", proc = () => %(), location = .%},\n", it.name, it.name, it.location);
    }
    print_to_builder(*builder, "];\n");

    return builder_to_string(*builder);
}

message_loop :: (builder: String_Builder)
{
    test_procs: [..] *Code_Procedure_Header;
    param_arrs: [..] Param_Array_Info;

    while true
    {
        message := compiler_wait_for_message();
        if message.kind ==
        {
            case .TYPECHECKED;
            typechecked := cast(*Message_Typechecked) message;

            for dc: typechecked.declarations
            {
                decl := dc.expression;
                if decl.type_inst == null continue;

                if (decl.flags & .IS_GLOBAL) &&
                    (decl.type_inst.result.type == .ARRAY) &&
                    (decl.type_inst.array_element_type.result.type == .STRUCT)
                {
                    arr_info := Param_Array_Info.{
                        name = decl.name,
                        count = decl.type_inst.result.(*Type_Info_Array).array_count,
                        element_type = get_type(decl.type_inst.array_element_type.result)
                    };
                    array_add(*param_arrs, arr_info);
                }
            }

            for tc: typechecked.procedure_headers
            {
                proc := tc.expression;
                if !has_note(proc, "Test") continue;

                array_add(*test_procs, proc);
            }

            case .PHASE;
            phase := cast(*Message_Phase) message;
            if phase.phase ==
            {
                case .TYPECHECKED_ALL_WE_CAN;
                if test_procs.count == 0 continue;

                tests: [..] Test;

                for proc: test_procs
                {
                    test := Test.{
                        name = proc.name,
                        location = .{
                            fully_pathed_filename = proc.enclosing_load.fully_pathed_filename,
                            line_number = proc.l0,
                            character_number = proc.c0
                        }
                    };

                    if proc.arguments.count > 0
                    {
                        add_parameterized_tests(proc, test, *tests, param_arrs);
                    }
                    else array_add(*tests, test);
                }

                add_build_string(create_test_string(tests, builder), message.workspace);
                test_procs.count = 0;
            }

            case .COMPLETE; break;
        }
    }
}

add_parameterized_tests :: (proc: *Code_Procedure_Header, base_test: Test, tests: *[..] Test, param_arrs: [] Param_Array_Info)
{
    test_param_type := get_type(proc.arguments[0].type_inst.result);

    for arr: param_arrs
    {
        if arr.element_type != test_param_type continue;

        for 0..arr.count - 1
        {
            test := base_test;
            test.is_parameterized = true;
            test.parameter_array_name = arr.name;
            test.parameter_index = it;

            array_add(tests, test);
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

    for 0..num_indents-1 print_to_builder(*builder, "    ");
    print_to_builder(*builder, str);
    return builder_to_string(*builder);
}

EXEC_STRING :: #string
HERE
#import "Basic";

main :: ()
{
    Verifai.print_test_info(test_files, tests.count);
    Verifai.run_tests(tests);
}
HERE

RUN_STRING :: #string
HERE
#run
{
    #import "Verifai";
    print_test_info(test_files, tests.count);
    run_tests(tests);
}
HERE

#import "Basic";
#import "Sort";
#import "Compiler";
#import "Program_Print";
#import "File_Utilities";
#import "Print_Color";
