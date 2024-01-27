{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Builds exposing (view, viewHeader)

import Components.Build
import Html
    exposing
        ( Html
        , a
        , br
        , code
        , div
        , em
        , h1
        , input
        , label
        , li
        , ol
        , p
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , checked
        , class
        , for
        , href
        , id
        , name
        , type_
        )
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Shared
import String
import Utils.Helpers as Util
import Vela



-- TYPES


type alias Msgs msg =
    { approveBuild : Vela.Org -> Vela.Repo -> Vela.BuildNumber -> msg
    , restartBuild : Vela.Org -> Vela.Repo -> Vela.BuildNumber -> msg
    , cancelBuild : Vela.Org -> Vela.Repo -> Vela.BuildNumber -> msg
    , showHideActionsMenus : Maybe Int -> Maybe Bool -> msg
    }


type alias Props msg =
    { msgs : Msgs msg
    , builds : WebData (List Vela.Build)
    , maybeEvent : Maybe String
    , showFullTimestamps : Bool
    , viewActionsMenu : Vela.Build -> Maybe (Html msg)
    }



-- VIEW


view : Shared.Model -> Props msg -> Html msg
view shared props =
    let
        webhooks =
            text "configured webhook events"

        -- case props.maybeRepo of
        --     Just repo ->
        --         a [ href <| "/" ++ String.join "/" [ props.org, repo ] ++ "/settings" ] [ text "configured webhook events" ]
        --     Nothing ->
        --         text "configured webhook events"
        none : Html msg
        none =
            case props.maybeEvent of
                Nothing ->
                    div []
                        [ p [] [ text "Builds will show up here once you have:" ]
                        , ol [ class "list" ]
                            [ li []
                                [ text "A "
                                , code [] [ text ".vela.yml" ]
                                , text " file that describes your build pipeline in the root of your repository."
                                , br [] []
                                , a [ href "https://go-vela.github.io/docs/usage/" ] [ text "Review the documentation" ]
                                , text " for help or "
                                , a [ href "https://go-vela.github.io/docs/usage/examples/" ] [ text "check some of the pipeline examples" ]
                                , text "."
                                ]
                            , li []
                                [ text "Trigger one of the "
                                , webhooks
                                , text " by performing the respective action via "
                                , em [] [ text "Git" ]
                                , text "."
                                ]
                            ]
                        , p [] [ text "Happy building!" ]
                        ]

                Just event ->
                    div []
                        [ h1 [] [ text <| "No builds for \"" ++ event ++ "\" event found." ] ]
    in
    case props.builds of
        RemoteData.Success builds ->
            if List.length builds == 0 then
                none

            else
                div [ class "builds", Util.testAttribute "builds" ] <|
                    List.map
                        (\build ->
                            Components.Build.view shared
                                { build = RemoteData.succeed build
                                , showFullTimestamps = props.showFullTimestamps
                                , actionsMenu = props.viewActionsMenu build
                                }
                        )
                        builds

        RemoteData.Loading ->
            Util.largeLoader

        RemoteData.NotAsked ->
            Util.largeLoader

        RemoteData.Failure _ ->
            div [ Util.testAttribute "builds-error" ]
                [ p []
                    [ text "There was an error fetching builds, please refresh or try again later!"
                    ]
                ]


viewHeader :
    { maybeEvent : Maybe String
    , showFullTimestamps : Bool
    , filterByEvent : Maybe String -> msg
    , showHideFullTimestamps : msg
    }
    -> Html msg
viewHeader props =
    div [ class "build-bar" ]
        [ viewFilter props.maybeEvent props.filterByEvent
        , viewTimeToggle props.showFullTimestamps props.showHideFullTimestamps
        ]


viewFilter : Maybe String -> (Maybe String -> msg) -> Html msg
viewFilter maybeEvent filterByEventMsg =
    let
        eventToMaybe event =
            case event of
                "all" ->
                    Nothing

                _ ->
                    Just event

        eventEnum =
            [ "all"
            , "push"
            , "pull_request"
            , "tag"
            , "deployment"
            , "schedule"
            , "comment"
            ]
    in
    div [ class "form-controls", class "build-filters", Util.testAttribute "build-filter" ] <|
        div [] [ text "Filter by Event:" ]
            :: List.map
                (\e ->
                    div [ class "form-control" ]
                        [ input
                            [ type_ "radio"
                            , id <| "filter-" ++ e
                            , name "build-filter"
                            , Util.testAttribute <| "build-filter-" ++ e
                            , checked <| maybeEvent == eventToMaybe e
                            , onClick <| filterByEventMsg (eventToMaybe e)
                            , attribute "aria-label" <| "filter to show " ++ e ++ " events"
                            ]
                            []
                        , label
                            [ class "form-label"
                            , for <| "filter-" ++ e
                            ]
                            [ text <| String.replace "_" " " e ]
                        ]
                )
                eventEnum


viewTimeToggle : Bool -> msg -> Html msg
viewTimeToggle showTimestamp showHideFullTimestampMsg =
    div [ class "form-controls", class "-stack", class "time-toggle" ]
        [ div [ class "form-control" ]
            [ input [ type_ "checkbox", checked showTimestamp, onClick showHideFullTimestampMsg, id "checkbox-time-toggle", Util.testAttribute "time-toggle" ] []
            , label [ class "form-label", for "checkbox-time-toggle" ] [ text "show full timestamps" ]
            ]
        ]
