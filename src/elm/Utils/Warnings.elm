{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Warnings exposing
    ( Warning
    , fromString
    )

{-|

@docs Warning
@docs fromString

-}

-- TYPES


{-| Warning : an object that represents a point of focus.
-}
type alias Warning =
    { maybeLineNumber : Maybe Int
    , content : String
    }



-- HELPERS


{-| fromString : parses a warning string into a line number and a message.
-}
fromString : String -> Warning
fromString warning =
    case String.split ":" warning of
        prefix :: content ->
            case String.toInt prefix of
                Just lineNumber ->
                    { maybeLineNumber = Just lineNumber, content = String.concat content }

                Nothing ->
                    { maybeLineNumber = Nothing, content = warning }

        _ ->
            { maybeLineNumber = Nothing, content = warning }
