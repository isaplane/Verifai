# Verifai

A(nother) unit testing module for Jai.

## Features
- Automatically gathers tests with @Test note
- Parameterized tests
- Colorized output
- Tests can be run at compile time (as part of normal build) or as a separate executable for debugging
- Test execution does not stop on failing test
- Tests can have multiple asserts. Test is marked as failing if any assert fails.

## Usage
Files with tests live in a single directory (specified in build file).

See the build_test_runner.jai and build_test_executable.jai files for examples on how to build for compile-time or standalone testing.
The build_test_runner.jai can be added to any build file by simply using the \#load directive.

### Setup and teardown procedures
To use setup and teardown procedures, tag one procedure per file with either @Setup or @Teardown.
These procedures will run before and after every test, respectively.

The setup procedure signature must include a return value of Any (although it does not need to be used by your tests). 
A custom struct can be defined and returned from the setup procedure as an Any type, which is stored in the `context.setup_data` field (reinitialized for each test).
This data does not need to be allocated on the heap.
Setup can also be used to initialize global- or file-scoped variables.

The teardown procedure must accept an Any type, which is the same data that is returned from the setup procedure.

Note that there are no naming restrictions for the setup/teardown procs, or the setup data struct.

Example:
```jai
Setup_Data :: struct
{
    str: string;
    num: int;
}

setup_test :: () -> Any
{
    return Setup_Data.{
        str = "Hello, Sailor!\n",
        num = 10
    };
} @Setup

teardown_test :: (setup_data: Any)
{
} @Teardown

setup_teardown_test :: ()
{
    setup := context.setup_data.value_pointer.(*Setup_Data);

    val := 10;
    Verifai.are_equal(val, setup.num);
} @Test
```


### Non-parameterized tests
Defined with no parameters or return types, and tagged with a @Test note.

Example:
```jai
is_true_test :: ()
{
    Verifai.is_true(2 > 1);
} @Test

is_false_test :: ()
{
    Verifai.is_false(2 == 1);
} @Test

are_equal_test :: ()
{
    Verifai.are_equal(2 + 2, 4);
} @Test

are_not_equal_test :: ()
{
    Verifai.are_not_equal(2 + 2, 3);
} @Test

are_equal_array_test :: ()
{
    arr_1: [1] int = .[8];
    arr_2: [1] int = .[8];

    comparator :: (a: [] int, b: [] int) -> bool
    {
        if a.count != b.count return false;
        for 0 .. a.count - 1
        {
            if a[it] != b[it] return false;
        }

        return true;
    }

    Verifai.are_equal(arr_1, arr_2, comparator);
} @Test

silly_test_proc :: ()
{
    val := null;
    Verifai.is_not_null(val);
} @Test

test_not_test_proc :: ()
{
} @Test

Verifai :: #import "Verifai";
```

Output:
```
Found 1 files with 7 tests.

Included files:
    - tests/test.jai


tests/test.jai:
    pass: is_true_test
    pass: is_false_test
    pass: are_equal_test
    pass: are_not_equal_test
    pass: are_equal_array_test
    fail: silly_test_proc
        Failing expression (line 52): Verifai.is_not_null(val)
    skip: test_not_test_proc
        Missing a test expression!

Ran 7 tests in 0 ms.
5 passed, 1 failed, 1 skipped.
```

### Parameterized tests
Defined with a single, unique, struct argument, no return type, and tagged with the same @Test note.
A global array with the same struct type is used to define parameters for each test case.

No naming requirements for the struct or array, as long as the type is unique and matches the parameter in the test procedure.

Example:
```jai
Example_Parameterized_Test_Case :: struct
{
    example_parameter: int;
}

example_arr: [2] Example_Parameterized_Test_Case = .[
    .{example_parameter = 1},
    .{example_parameter = 0}
];

example_parameterized_test :: (param: Example_Parameterized_Test_Case)
{
    Verifai.is_true(param.example_parameter > 0);
} @Test

// -----------------------------------------------------------------------------

Another_Example_Parameterized_Test_Case :: struct
{
    example_parameter: int;
}

another_example_arr: [2] Another_Example_Parameterized_Test_Case = .[
    .{example_parameter = 1},
    .{example_parameter = 2}
];

another_example_parameterized_test :: (param: Another_Example_Parameterized_Test_Case)
{
    Verifai.is_true(param.example_parameter > 0);
} @Test

// -----------------------------------------------------------------------------

Yet_Another_Example_Parameterized_Test_Case :: struct
{
    example_parameter: int;
}

yet_another_example_arr: [2] Yet_Another_Example_Parameterized_Test_Case = .[
    .{example_parameter = 1},
    .{example_parameter = 2}
];

yet_another_example_parameterized_test :: (param: Yet_Another_Example_Parameterized_Test_Case)
{
} @Test

Verifai :: #import "Verifai";
```

Output:
```
Found 1 files with 6 tests.

Included files:
    - tests/test.jai


tests/test.jai:
    fail: example_parameterized_test
        pass: Parameter index 0
        fail: Parameter index 1
            Failing expression (line 82): Verifai.is_true(param.example_parameter > 0)
    pass: another_example_parameterized_test
        pass: Parameter index 0
        pass: Parameter index 1
    skip: yet_another_example_parameterized_test
        skip: Parameter index 0
            Missing a test expression!
        skip: Parameter index 1
            Missing a test expression!

Ran 6 tests in 0 ms.
3 passed, 1 failed, 2 skipped.
```

## Other testing modules
I took a lot of inspiration from these existing Jai unit test modules, and tried to implement my favorite parts of each one using the simplest code I could:
- Assertive: https://github.com/dbechrd/jai-assertive/tree/master
- Unotest: https://github.com/n00bmind/unotest/tree/main
- Stubborn: https://github.com/rluba/stubborn/tree/master

Please consider checking these out if this module doesn't fit your use case!

## TODO
- Print expression & parameter values in test output
