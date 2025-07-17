begin_test_workspace :: (executable_name: string) -> Workspace
{
    w := compiler_create_workspace("tests_workspace");
    assert(w > 0, "Bad workspace.\n");

    target_options := get_build_options(w);
    target_options.output_executable_name = executable_name;
    set_build_options(target_options, w);

    return w;
}

end_test_workspace :: (w: Workspace)
{
    add_build_string(BUILD_STRING, w);
}

BUILD_STRING :: #string
HERE
#import "Basic";

main :: ()
{
    print("Hello, Sailor!\n");
}
HERE

#import "Basic";
#import "Compiler";

