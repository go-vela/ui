{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Name exposing (disallowedNameCharacters, disallowedNameCharactersText, sanitizeName)

import List
import String


{-| Characters that are disallowed in resource names because the backend
escapes them and loses fidelity when values are persisted.
-}
disallowedNameCharacters : List Char
disallowedNameCharacters =
    [ '\''
    , '"'
    , '&'
    , '<'
    , '>'
    ]


{-| String representation of `disallowedNameCharacters` for displaying to users.
-}
disallowedNameCharactersText : String
disallowedNameCharactersText =
    disallowedNameCharacters
        |> List.map String.fromChar
        |> String.join " "


{-| Removes characters that are known to be unsupported by the backend from the
supplied name string.
-}
sanitizeName : String -> String
sanitizeName name =
    name
        |> String.toList
        |> List.filter (\char -> not <| List.member char disallowedNameCharacters)
        |> String.fromList
