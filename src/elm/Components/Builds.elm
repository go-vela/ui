{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Builds exposing (view, viewHeader)

import Components.Build
import Components.Loading
import Html
    exposing
        ( Html
        , a
        , br
        , code
        , div
        , em
        , h2
        , h3
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


{-| Msgs : alias for an object representing multiple messages.
-}
type alias Msgs msg =
    { approveBuild : { org : Vela.Org, repo : Vela.Repo, build : Vela.BuildNumber } -> msg
    , restartBuild : { org : Vela.Org, repo : Vela.Repo, build : Vela.BuildNumber } -> msg
    , cancelBuild : { org : Vela.Org, repo : Vela.Repo, build : Vela.BuildNumber } -> msg
    , showHideActionsMenus : Maybe Int -> Maybe Bool -> msg
    }


{-| Props : alias for an object representing properties for a builds component.
-}
type alias Props msg =
    { msgs : Msgs msg
    , builds : WebData (List Vela.Build)
    , orgRepo : ( String, Maybe String )
    , maybeEvent : Maybe String
    , showFullTimestamps : Bool
    , viewActionsMenu : { build : Vela.Build } -> Html msg
    , showRepoLink : Bool
    , linkBuildNumber : Bool
    }



-- VIEW


{-| view : renders repo builds list, or instructions if no builds.
-}
view : Shared.Model -> Props msg -> Html msg
view shared props =
    let
        noBuildsHeaderText =
            case props.orgRepo of
                ( _, Just _ ) ->
                    text "Your repository has been enabled!"

                _ ->
                    text "No builds were found for this organization!"

        webhooks =
            case props.orgRepo of
                ( org, Just repo ) ->
                    a [ href <| "/" ++ String.join "/" [ org, repo ] ++ "/settings" ] [ text "configured webhook events" ]

                _ ->
                    text "configured webhook events"

        none : Html msg
        none =
            case props.maybeEvent of
                Nothing ->
                    div []
                        [ h2 [] [ noBuildsHeaderText ]
                        , p [] [ text "Builds will show up here once you have:" ]
                        , ol [ class "list" ]
                            [ li []
                                [ text "A "
                                , code [] [ text ".vela.yml" ]
                                , text " file that describes your build pipeline in the root of your repository."
                                , br [] []
                                , a [ href <| shared.velaDocsURL ++ "/usage/" ] [ text "Review the documentation" ]
                                , text " for help or "
                                , a [ href <| shared.velaDocsURL ++ "/usage/examples/" ] [ text "check some of the pipeline examples" ]
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
                        [ h3 [] [ text <| "No builds for \"" ++ event ++ "\" event found." ] ]
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
                                , actionsMenu = props.viewActionsMenu { build = build }
                                , showRepoLink = props.showRepoLink
                                , linkBuildNumber = props.linkBuildNumber
                                }
                        )
                        builds

        RemoteData.Loading ->
            Components.Loading.viewSmallLoader

        RemoteData.NotAsked ->
            Components.Loading.viewSmallLoader

        RemoteData.Failure _ ->
            div [ Util.testAttribute "builds-error" ]
                [ p []
                    [ text "There was an error fetching builds, please refresh or try again later!"
                    ]
                ]


{-| viewHeader : renders builds header including filter and timestamp toggle.
-}
viewHeader :
    { show : Bool
    , maybeEvent : Maybe String
    , showFullTimestamps : Bool
    , filterByEvent : Maybe String -> msg
    , showHideFullTimestamps : msg
    }
    -> Html msg
viewHeader props =
    if props.show then
        div [ class "builds-header" ]
            [ viewFilter props.maybeEvent props.filterByEvent
            , viewTimeToggle props.showFullTimestamps props.showHideFullTimestamps
            ]

    else
        text ""


{-| viewFilter : renders filter values to filter build list.
-}
viewFilter : Maybe String -> (Maybe String -> msg) -> Html msg
viewFilter maybeEvent filterByEventMsg =
    let
        eventToMaybe event =
            case event of
                "all" ->
                    Nothing

                _ ->
                    Just event
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
                Vela.allowEventsFilterQueryKeys


{-| viewTimeToggle : renders checkbox to toggle between relative time and absolute time.
-}
viewTimeToggle : Bool -> msg -> Html msg
viewTimeToggle showTimestamp showHideFullTimestampMsg =
    div [ class "form-controls", class "-stack", class "time-toggle" ]
        [ div [ class "form-control" ]
            [ input [ type_ "checkbox", checked showTimestamp, onClick showHideFullTimestampMsg, id "checkbox-time-toggle", Util.testAttribute "time-toggle" ] []
            , label [ class "form-label", for "checkbox-time-toggle" ] [ text "show full timestamps" ]
            ]
        ]
