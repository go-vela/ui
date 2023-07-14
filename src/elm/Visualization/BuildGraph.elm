module Visualization.BuildGraph exposing (toDOT)

import Dict exposing (Dict)
import Focus
import Graph exposing (Edge, Node)
import List.Extra
import Pages.Build.Model as BuildModel
import Pages.Build.View
import Routes exposing (Route(..))
import SvgBuilder exposing (buildStatusToIcon)
import Url.Builder as UB
import Vela
    exposing
        ( Build
        , BuildGraph
        , BuildGraphEdge
        , BuildGraphNode
        , Step
        , statusToString
        )
import Visualization.DOT as DOT exposing (Attribute(..), AttributeValue(..), escapeAttributes, escapeCharacters, outputWithStylesAndAttributes)


{-| toDOT : takes model and build graph, and returns a string representation of a DOT graph using the extended Graph DOT package
<https://graphviz.org/doc/info/lang.html>
<https://package.elm-lang.org/packages/elm-community/graph/latest/Graph.DOT>
-}
toDOT : BuildModel.PartialModel a -> BuildGraph -> String
toDOT model buildGraph =
    let
        baseStyles : DOT.Styles
        baseStyles =
            { rankdir = DOT.LR
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

                    -- , ( "regular", DefaultEscape "true" )
                    ]
            , edge =
                escapeAttributes
                    [ ( "color", DefaultEscape "azure2" )
                    , ( "penwidth", DefaultEscape "1" )
                    , ( "arrowhead", DefaultEscape "dot" )
                    , ( "arrowsize", DefaultEscape "0.5" )
                    , ( "minlen", DefaultEscape "2" )
                    ]
            }

        nodeAttrs : BuildGraphNode -> Dict String Attribute
        nodeAttrs n =
            let
                showSteps =
                    Maybe.withDefault True <| Dict.get n.name model.repo.build.graph.showSteps

                -- if List.length n.steps == 1 then
                --     True
                -- else if List.length n.steps > 1 then
                --     Maybe.withDefault False <| Dict.get n.name model.repo.build.graph.showSteps
                -- else
                --     False
                stageStatus =
                    if List.any (\s -> s.status == Vela.Running) n.steps then
                        "running"

                    else if List.any (\s -> s.status == Vela.Failure) n.steps then
                        "failure"

                    else if List.any (\s -> s.status == Vela.Success) n.steps then
                        "success"

                    else if List.any (\s -> s.status == Vela.Killed) n.steps then
                        "killed"

                    else
                        "pending"
            in
            Dict.fromList <|
                [ ( "class", DefaultJSONLabelEscape "stage-node" )
                , ( "id", DefaultJSONLabelEscape <| "#" ++ stageStatus )
                , ( "shape", DefaultJSONLabelEscape "rect" )
                , ( "style", DefaultJSONLabelEscape "filled" )
                , ( "label", HtmlLabelEscape <| buildLabel model n.name n.steps showSteps )
                , ( "href", DefaultJSONLabelEscape ("#" ++ n.name) )
                , ( "border", DefaultJSONLabelEscape "white" )

                -- , ( "group", DefaultJSONLabelEscape (String.fromInt <| if String.contains "batch" n.name then 1 else 2 ))
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


buildLabel : BuildModel.PartialModel a -> String -> List Step -> Bool -> String
buildLabel model label steps_ showSteps =
    let
        -- steps =
        --     debugSteps
        steps =
            List.sortBy .id steps_

        table body =
            "<TABLE "
                ++ escapeAttributes
                    [ ( "BORDER", DefaultEscape "0" )
                    , ( "CELLBORDER", DefaultEscape "0" )
                    , ( "CELLSPACING", DefaultEscape "5" )
                    , ( "MARGIN", DefaultEscape "0" )
                    ]
                ++ ">"
                ++ String.join "" body
                ++ "</TABLE>"

        src =
            UB.absolute [ "post.png" ] []

        fontcolor =
            "white"

        header attrs body =
            "<TR><TD  " ++ attrs ++ ">" ++ body ++ "</TD></TR>"

        row rowAttrs cellAttrs body step =
            "<TR "
                ++ rowAttrs
                ++ " >"
                -- ++ "<TD ALIGN='LEFT' BALIGN='LEFT' BGCOLOR='BLACK'"
                -- ++ " PORT='"
                -- ++ String.fromInt step.id
                -- ++ "' >"
                -- ++ "<font COLOR='"
                -- ++ fontcolor
                -- ++ "'>xyz123-"
                -- ++ Pages.Build.View.statusToString step.status
                -- ++ "</font>"
                -- ++ "</TD>"
                -- ++ " <TD "
                -- ++ escapeAttributes
                --     [ ( "BORDER", DefaultEscape "0" )
                --     , ( "CELLBORDER", DefaultEscape "0" )
                --     , ( "CELLSPACING", DefaultEscape "0" )
                --     , ( "MARGIN", DefaultEscape "0" )
                --     , ( "ALIGN", DefaultEscape "left" )
                --     , ( "HREF", DefaultEscape "link" )
                --     , ( "TOOLTIP", DefaultEscape "node" )
                --     , ( "ID", DefaultEscape "step-icon" )
                --     -- , ( "BGCOLOR", DefaultEscape "red" )
                --     ]
                -- ++ " >.</TD> "
                ++ "<TD "
                ++ cellAttrs
                ++ " "
                ++ ">"
                -- ++ "<TD "
                -- ++ escapeAttributes
                --     [ ( "ID", DefaultEscape "row-icon" )
                --     ]
                -- ++ " >"
                ++ "&nbsp;&nbsp;"
                -- ++ " </TD>"
                -- ++ "<font color='white'>"
                -- ++ String.fromInt step.id
                -- ++ "</font>"
                -- ++ ":"
                ++ "<font color='white'>"
                ++ step.name
                ++ "</font>"
                ++ "<BR ALIGN='LEFT'/>"
                ++ "</TD>"
                ++ "</TR>"

        labelColor =
            "white"

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
                [ if List.length steps_ > 1 then
                    header
                        (escapeAttributes
                            [ ( "ALIGN", DefaultEscape "left" ) ]
                        )
                        ("<font color='"
                            ++ labelColor
                            ++ "'>"
                            ++ "<U>"
                            ++ label
                            ++ "</U>"
                            ++ "</font>"
                        )

                  else
                    header
                        (escapeAttributes
                            [ ( "ALIGN", DefaultEscape "left" ) ]
                        )
                        ("<font color='"
                            ++ labelColor
                            ++ "'>"
                            ++ "<U>"
                            ++ label
                            ++ "</U>"
                            ++ "</font>"
                        )

                -- , "<TR><TD rowspan='" ++ (String.fromInt <| 1 + (List.length steps))++ "'><font color='white'>.</font></TD></TR>"
                ]
                    ++ (if showSteps then
                            List.map
                                (\step ->
                                    let
                                        link =
                                            Routes.routeToUrl <| Routes.Build model.repo.org model.repo.name model.repo.build.buildNumber (Just <| Focus.resourceFocusFragment "step" (String.fromInt step.number) [])
                                    in
                                    row
                                        (escapeAttributes
                                            [ ( "ID", DefaultEscape "node-row" ) ]
                                        )
                                        (escapeAttributes
                                            [ ( "BORDER", DefaultEscape "0" )
                                            , ( "CELLBORDER", DefaultEscape "0" )
                                            , ( "CELLSPACING", DefaultEscape "0" )
                                            , ( "MARGIN", DefaultEscape "0" )
                                            , ( "ALIGN", DefaultEscape "left" )
                                            , ( "HREF", DefaultEscape link )
                                            , ( "ID", DefaultEscape "node-cell" )
                                            , ( "TITLE", DefaultEscape ("#status-" ++ statusToString step.status) )
                                            , ( "TOOLTIP", DefaultEscape (String.join "," [ String.fromInt step.id, step.name, statusToString step.status ]) )

                                            -- , ( "SCALE", DefaultEscape "BOTH" )
                                            -- , ( "BGCOLOR"
                                            --   , DefaultEscape <|
                                            --         case step.status of
                                            --             Vela.Success ->
                                            --                 "#7dd123"
                                            --             Vela.Failure ->
                                            --                 "#b5172a"
                                            --             Vela.Error ->
                                            --                 "#b5172a"
                                            --             Vela.Running ->
                                            --                 "#ffcc00"
                                            --             Vela.Killed ->
                                            --                 "PURPLE"
                                            --             Vela.Pending ->
                                            --                 "GRAY"
                                            --             Vela.Canceled ->
                                            --                 "#b5172a"
                                            --   )
                                            ]
                                        )
                                        step.name
                                        step
                                )
                                steps

                        else
                            []
                       )
    in
    stuff


debugSteps =
    let
        ds =
            Vela.defaultStep
    in
    [ { ds | name = "golang build", status = Vela.Success, id = 69 }
    , { ds | name = "docker_promote", status = Vela.Failure, id = 701 }
    , { ds | name = "wrap-up", status = Vela.Pending, id = 7100 }
    , { ds | name = "slack-notification", status = Vela.Pending, id = 720123 }
    ]
