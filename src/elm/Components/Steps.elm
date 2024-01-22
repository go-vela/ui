module Components.Steps exposing (..)

import Components.Logs
import Components.Svgs
import Dict exposing (Dict)
import FeatherIcons
import Html exposing (Html, details, div, small, summary, text)
import Html.Attributes exposing (attribute, class, classList, id)
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Shared
import Utils.Helpers as Util
import Vela


type alias Msgs msg =
    { expandStep : { step : Vela.Step, updateUrlHash : Bool } -> msg
    , collapseStep : { step : Vela.Step, updateUrlHash : Bool } -> msg
    , expandSteps : msg
    , collapseSteps : msg
    , focusLogLine : { identifier : String } -> msg
    , downloadLog : { filename : String, content : String, map : String -> String } -> msg
    }


type alias Props msg =
    { msgs : Msgs msg
    , steps : WebData (List Vela.Step)
    , logs : Dict Int (WebData Vela.Log)
    , org : String
    , repo : String
    , buildNumber : String
    , logLineFocus : ( Maybe Int, ( Maybe Int, Maybe Int ) )
    }


view : Shared.Model -> Props msg -> Html msg
view shared props =
    div []
        [ div
            [ class "buttons"
            , class "log-actions"
            , class "flowline-left"
            , Util.testAttribute "log-actions"
            ]
            [ Html.button
                [ class "button"
                , class "-link"
                , onClick props.msgs.collapseSteps
                , Util.testAttribute "collapse-all"
                ]
                [ small [] [ text "collapse all" ] ]
            , Html.button
                [ class "button"
                , class "-link"
                , onClick props.msgs.expandSteps
                , Util.testAttribute "expand-all"
                ]
                [ small [] [ text "expand all" ] ]
            ]
        , div [ class "steps" ]
            [ div [ class "-items", Util.testAttribute "steps" ] <|
                List.map (viewStep shared props) <|
                    List.sortBy .number <|
                        RemoteData.withDefault [] props.steps

            -- if hasStages steps then
            --     viewStages model msgs rm steps
            -- else
            -- List.map viewStep<| steps
            ]
        ]


viewStep : Shared.Model -> Props msg -> Vela.Step -> Html msg
viewStep shared props step =
    let
        stepNumber =
            String.fromInt step.number

        clickStep =
            if step.viewing then
                props.msgs.collapseStep

            else
                props.msgs.expandStep
    in
    div [ classList [ ( "step", True ), ( "flowline-left", True ) ], Util.testAttribute "step" ]
        [ div [ class "-status" ]
            [ div [ class "-icon-container" ] [ Components.Svgs.stepStatusToIcon step.status ] ]
        , details
            (classList
                [ ( "details", True )
                , ( "-with-border", True )
                , ( "-running", step.status == Vela.Running )
                ]
                :: Util.open step.viewing
            )
            [ summary
                [ class "summary"
                , Util.testAttribute <| "step-header-" ++ stepNumber
                , onClick <| clickStep { step = step, updateUrlHash = True }
                , id <| "step-" ++ stepNumber
                ]
                [ div
                    [ class "-info" ]
                    [ div [ class "-name" ] [ text step.name ]
                    , div [ class "-duration" ] [ text <| Util.formatRunTime shared.time step.started step.finished ]
                    ]
                , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml [ attribute "aria-label" "show build actions" ]
                ]
            , div [ class "logs-container" ]
                [ viewLogs shared props step <|
                    Maybe.withDefault RemoteData.Loading <|
                        Dict.get step.id props.logs
                ]
            ]
        ]


viewLogs : Shared.Model -> Props msg -> Vela.Step -> WebData Vela.Log -> Html msg
viewLogs shared props step log =
    case step.status of
        Vela.Error ->
            div [ class "message", class "error", Util.testAttribute "resource-error" ]
                [ text <|
                    "error: "
                        ++ (if String.isEmpty step.error then
                                "null"

                            else
                                step.error
                           )
                ]

        Vela.Killed ->
            div [ class "message", class "error", Util.testAttribute "step-skipped" ]
                [ text "step was skipped" ]

        _ ->
            Components.Logs.view
                shared
                { msgs =
                    { focusLine = props.msgs.focusLogLine
                    , download = props.msgs.downloadLog
                    }
                , log = log
                , org = props.org
                , repo = props.repo
                , buildNumber = props.buildNumber
                , resourceNumber = String.fromInt step.number
                , resourceType = "step"
                , lineFocus =
                    if step.number == Maybe.withDefault -1 (Tuple.first props.logLineFocus) then
                        Just <| Tuple.second props.logLineFocus

                    else
                        Nothing
                }
