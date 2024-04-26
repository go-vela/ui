module Utils.Routes exposing (pathFromString)

import Maybe.Extra
import Url


{-| pathFromString : takes a string and returns a curated path record using path query and fragment (hash)
-}
pathFromString :
    String
    ->
        { path : String
        , query : Maybe String
        , hash : Maybe String
        }
pathFromString urlString =
    let
        toPath u =
            u
                |> Url.fromString
                |> Maybe.map (\u_ -> { path = u_.path, query = u_.query, hash = u_.fragment })
    in
    urlString
        |> Maybe.Extra.oneOf
            [ toPath
            , String.append "http://" >> toPath
            , String.append "http://example.com" >> toPath
            ]
        |> Maybe.withDefault { path = "/", query = Nothing, hash = Nothing }
