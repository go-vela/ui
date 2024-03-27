module Utils.Routes exposing (pathFromString)


pathFromString :
    String
    ->
        { path : String
        , query : Maybe String
        , hash : Maybe String
        }
pathFromString urlString =
    let
        pathsAndHash =
            String.split "#" urlString

        maybeHash =
            List.head <| List.drop 1 pathsAndHash

        pathsAndQuery =
            String.split "?" <| Maybe.withDefault "" <| List.head pathsAndHash

        pathSegments =
            String.split "/" <| Maybe.withDefault "" <| List.head pathsAndQuery

        maybeQuery =
            List.head <| List.drop 1 pathsAndQuery
    in
    { path = String.join "/" pathSegments, query = maybeQuery, hash = maybeHash }
