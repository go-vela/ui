module Test exposing (testNone)

import Expect
import Test exposing (..)


testNone : Test
testNone =
    test "placeholder test" <|
        \_ ->
            Expect.equal "abc123" "abc123"
