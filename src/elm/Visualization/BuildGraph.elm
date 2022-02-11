module Visualization.BuildGraph exposing (toDOT)

import Dict exposing (Dict)
import Focus
import Graph exposing (Edge, Node)
import List.Extra
import Pages.Build.Model as BuildModel
import Routes exposing (Route(..))
import SvgBuilder exposing (buildStatusToIcon)
import Url.Builder as UB
import Vela exposing (Build, BuildGraph, BuildGraphEdge, BuildGraphNode, Step)
import Visualization.DOT as DOT exposing (Attribute(..), AttributeValue(..), escapeAttributes, escapeCharacters, outputWithStylesAndAttributes)
import Pages.Build.View

{-| toDOT : takes model and build graph, and returns a string representation of a DOT graph using the extended Graph DOT package
<https://graphviz.org/doc/info/lang.html>
<https://package.elm-lang.org/packages/elm-community/graph/latest/Graph.DOT>
-}
toDOT : BuildModel.PartialModel a -> BuildGraph -> String
toDOT model buildGraph =
    let
        baseStyles : DOT.Styles
        baseStyles =
            { rankdir = DOT.TB
            , graph =
                escapeAttributes
                    [ ( "bgcolor", DefaultEscape "transparent" )
                    -- , ( "compound", BooleanEscape "true" )
                    , ( "splines", DefaultEscape "ortho" )
                    ]
            , node =
                escapeAttributes
                    [ ( "color", DefaultEscape "#151515" )
                    , ( "style", DefaultEscape "filled" )
                    -- , ( "tooltip", DefaultEscape " " )
                    , ( "fontname", DefaultEscape "Arial" )
                    -- , ( "fontcolor", DefaultEscape "#FFFFFF" )
                    ]
            , edge =
                escapeAttributes
                    [ ( "color", DefaultEscape "azure2" )
                    , ( "penwidth", DefaultEscape "1" )
                    , ( "arrowhead", DefaultEscape "dot" )
                    , ( "arrowsize", DefaultEscape "0.25" )
                    ]
            }

        nodeAttrs : BuildGraphNode -> Dict String Attribute
        nodeAttrs n =
            Dict.fromList <|
                [ ( "class", DefaultJSONLabelEscape "stage-node" )
                , ( "shape", DefaultJSONLabelEscape "rect" )
                , ( "style", DefaultJSONLabelEscape "filled" )
                , ( "label", HtmlLabelEscape <| buildLabel model n.name n.steps )

                -- , ( "label", HtmlLabelEscape <| "\\l" ++  n.name)
                ]

        edges =
            List.map (\e -> Edge e.source e.destination ()) buildGraph.edges

        nodes =
            List.map (\( _, node ) -> Node node.id (BuildGraphNode node.id node.name node.steps)) <| Dict.toList buildGraph.nodes

        edgeAttrs _ =
            Dict.fromList <|
                [ ( "class", DefaultJSONLabelEscape "stage-edge" )
                ]
        graph =
            Graph.fromNodesAndEdges nodes edges
    in
    outputWithStylesAndAttributes baseStyles nodeAttrs edgeAttrs graph


buildLabel : BuildModel.PartialModel a -> String -> List Step -> String
buildLabel model label steps =
    let
        table body =
            "<TABLE "
                ++ escapeAttributes
                    [ 
                    ( "BORDER", DefaultEscape "0" )
                    , ( "CELLBORDER", DefaultEscape "0" )
                    , ( "CELLSPACING", DefaultEscape "0" )
                    , ( "MARGIN", DefaultEscape "0" )
                    ]
                ++ ">"
                ++ String.join "" body
                ++ "</TABLE>"

        src = UB.absolute [ "post.png"] []
        row attrs body step =
            "<TR><TD  ALIGN='LEFT' BALIGN='LEFT' fixedsize='true' width='16' height='16'>xyz123-" ++ (Pages.Build.View.statusToString step.status) ++ "</TD><TD " ++ attrs ++ ">" ++ body ++ "<BR ALIGN='LEFT'/></TD></TR>"

        header attrs body =
            "<TR><TD colspan='2' " ++ attrs ++ ">" ++ body ++ "</TD></TR>"



        stuff =
            -- if List.length steps == 1 && Maybe.withDefault "" (List.head <| List.map .name steps) == label then
            --     let
            --         head = List.head steps
            --         c =
            --             case head of
            --                 Just h ->
            --                     case h.status of 
            --                             Vela.Success ->
            --                                 "#7dd123"
            --                             Vela.Failure ->
            --                                 "#b5172a"
            --                             Vela.Error ->
            --                                 "#b5172a"
            --                             Vela.Running ->
            --                                 "#ffcc00"
            --                             Vela.Killed ->
            --                                 "PURPLE"
            --                             Vela.Pending ->
            --                                 "GRAY"
            --                             Vela.Canceled ->
            --                                 "#b5172a"
            --                 Nothing ->
            --                     "white"
            --     in
            --         table [ row "" <| "<font color='"++c++"'>" ++  label ++ "</font>" ]


            -- else
                table <|
                    header "" ( "<font color='white'>" ++  label ++ "</font>" )
                        :: List.map
                            (\step ->
                                let
                                    link =
                                        Routes.routeToUrl <| Routes.Build model.repo.org model.repo.name model.repo.build.buildNumber (Just <| Focus.resourceFocusFragment "step" (String.fromInt step.number) [])
                                in
                                row
                                    (escapeAttributes
                                        [ 
                                            ( "BORDER", DefaultEscape "0" )
                                            , ( "CELLBORDER", DefaultEscape "0" )
                                            , ( "CELLSPACING", DefaultEscape "0" )
                                            , ( "MARGIN", DefaultEscape "0" )
                                           , ( "ALIGN", DefaultEscape "left" )
                                           , ( "HREF", DefaultEscape link )
                                        ,
                                            ( "BGCOLOR"
                                          , DefaultEscape <|
                                                case step.status of 
                                                    Vela.Success ->
                                                        "#7dd123"
                                                    Vela.Failure ->
                                                        "#b5172a"
                                                    Vela.Error ->
                                                        "#b5172a"
                                                    Vela.Running ->
                                                        "#ffcc00"
                                                    Vela.Killed ->
                                                        "PURPLE"
                                                    Vela.Pending ->
                                                        "GRAY"
                                                    Vela.Canceled ->
                                                        "#b5172a"
                                          )
                                        ]
                                    )
                                    (step.name ) step
                            )
                            steps
    in
    stuff
