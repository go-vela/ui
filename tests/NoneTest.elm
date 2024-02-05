module NoneTest exposing (testNone)

import Expect
import Test exposing (..)


testNone : Test
testNone =
    test "placeholder 'None' test" <|
        \_ ->
            Expect.equal "abc123" "abc123"
