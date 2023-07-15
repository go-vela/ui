module Visualization.DOT exposing
    ( Attribute(..)
    , AttributeValue(..)
    , Rankdir(..)
    , Styles
    , clusterSubgraph
    , digraph
    , escapeAttributes
    , escapeCharacters
    )

-- TYPES


type alias Styles =
    { rankdir : Rankdir
    , graph : String
    , node : String
    , edge : String
    }


type Rankdir
    = TB
    | LR
    | BT
    | RL


type Attribute
    = DefaultJSONLabelEscape String
    | HtmlLabelEscape String


type AttributeValue
    = DefaultEscape String
    | BooleanEscape String



-- DOT HELPERS


digraph : Styles -> List String -> String
digraph styles content =
    String.join "\n" <|
        List.concat
            [ [ "digraph G {" -- start graph
              , "  compound=true" -- adds support for subgraph edges
              , "  rankdir=" ++ rankDirToString styles.rankdir
              , "  graph [" ++ styles.graph ++ "]"
              , "  node [" ++ styles.node ++ "]"
              , "  edge [" ++ styles.edge ++ "]"
              , ""
              ]
            , content
            , [ ""
              , "}" -- end graph
              , ""
              ]
            ]


clusterSubgraph : String -> Styles -> String -> String -> String
clusterSubgraph cluster styles nodesString edgesString =
    String.join "\n"
        [ "subgraph cluster_" ++ cluster ++ " {" -- start subgraph
        , "  graph [" ++ styles.graph ++ "]"
        , "  node [" ++ styles.node ++ "]"
        , "  edge [" ++ styles.edge ++ "]"
        , ""
        , edgesString
        , ""
        , nodesString
        , ""
        , "}" -- end subgraph
        ]


rankDirToString : Rankdir -> String
rankDirToString r =
    case r of
        TB ->
            "TB"

        LR ->
            "LR"

        BT ->
            "BT"

        RL ->
            "RL"


{-| escapeCharacters : takes string and escapes special characters to prepare for use in a DOT string
-}
escapeCharacters : String -> String
escapeCharacters s =
    s
        |> String.replace "&" "&amp;"
        |> String.replace "<" "&lt;"
        |> String.replace ">" "&gt;"
        |> String.replace "\"" "&quot;"
        |> String.replace "'" "&#039;"


{-| escapeAttributes : takes list of string attributes and escapes special characters for keys and values to prepare for use in a DOT string
-}
escapeAttributes : List ( String, AttributeValue ) -> String
escapeAttributes attrs =
    List.map
        (\( k, attrV ) ->
            case attrV of
                DefaultEscape v ->
                    escapeCharacters k ++ "=\"" ++ escapeCharacters v ++ "\""

                BooleanEscape v ->
                    escapeCharacters k ++ "=" ++ v ++ ""
        )
        attrs
        |> String.join " "
