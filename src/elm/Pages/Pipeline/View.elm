{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Pipeline.View exposing (view)

import Ansi.Log
import Array
import Dict
import Dict.Extra
import DateFormat.Relative exposing (relativeTime)
import Errors exposing (Error, detailedErrorToString)
import FeatherIcons exposing (Icon)
import Focus exposing (ExpandTemplatesQuery, Fragment, RefQuery, Resource, ResourceID, lineFocusStyles, lineRangeId, resourceAndLineToFocusId)
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , div
        , small
        , span
        , strong
        , table
        , td
        , text
        , tr
        )
import Time exposing (Zone, Posix)
import Nav exposing (viewBuildNav)
import Html.Attributes exposing (title, href, attribute, class)
import Html.Events exposing (onClick)
import List.Extra
import Pages exposing (Page(..))
import Pages.Build.Logs exposing (decodeAnsi)
import Pages.Build.View exposing (viewLine)
import Pages.Pipeline.Model exposing (Msg(..), PartialModel)
import RemoteData exposing (RemoteData(..), WebData)
import Routes exposing (Route(..))
import SvgBuilder
import Util
import Vela
    exposing
        ( Build
        , LogFocus
        , Org
        , Pipeline
        , PipelineConfig
        , Repo
        , Step
        , Steps,Status 
        , Template
        , Templates
        )
import SvgBuilder exposing (buildStatusToIcon)


-- VIEW



{-| view : renders entire build based on current application time
-}
view : PartialModel a -> Html Msg
view model  =
    let
        rm =
            model.repo

        build =
            rm.build

        ( buildPreview, buildNumber ) =
            case build.build of
                RemoteData.Success bld ->
                    ( viewPreview model.time model.zone rm.org rm.name bld, String.fromInt bld.number )

                RemoteData.Loading ->
                    ( Util.largeLoader, "" )

                _ ->
                    ( text "", "" )
        navTabs = 
            viewBuildNav rm model.page


        markdown =
            [ buildPreview
            , navTabs
            , viewPipeline model
            ]
    in
    div [ Util.testAttribute "full-build" ] markdown





{-| viewPreview : renders single build item preview based on current application time
-}
viewPreview : Posix -> Zone -> Org -> Repo -> Build -> Html Msg
viewPreview now zone org repo build =
    let
        buildNumber =
            String.fromInt build.number

        status =
            [ buildStatusToIcon build.status ]

        commit =
            [ text <| String.replace "_" " " build.event
            , text " ("
            , a [ href build.source ] [ text <| Util.trimCommitHash build.commit ]
            , text <| ")"
            ]

        branch =
            [ a [ href <| Util.buildBranchUrl build.clone build.branch ] [ text build.branch ] ]

        sender =
            [ text build.sender ]

        message =
            [ text <| "- " ++ build.message ]

        id =
            [ a
                [ Util.testAttribute "build-number"
                , Routes.href <| Routes.Build org repo buildNumber Nothing
                ]
                [ text <| "#" ++ buildNumber ]
            ]

        age =
            [ text <| relativeTime now <| Time.millisToPosix <| Util.secondsToMillis build.created ]

        buildCreatedPosix =
            Time.millisToPosix <| Util.secondsToMillis build.created

        timestamp =
            Util.humanReadableDateTimeFormatter zone buildCreatedPosix

        duration =
            [ text <| Util.formatRunTime now build.started build.finished ]

        statusClass =
            Pages.Build.View.statusToClass build.status

        markdown =
            [ div [ class "status", Util.testAttribute "build-status", statusClass ] status
            , div [ class "info" ]
                [ div [ class "row -left" ]
                    [ div [ class "id" ] id
                    , div [ class "commit-msg" ] [ strong [] message ]
                    ]
                , div [ class "row" ]
                    [ div [ class "git-info" ]
                        [ div [ class "commit" ] commit
                        , text "on"
                        , div [ class "branch" ] branch
                        , text "by"
                        , div [ class "sender" ] sender
                        ]
                    , div [ class "time-info" ]
                        [ div
                            [ class "age"
                            , title timestamp
                            ]
                            age
                        , span [ class "delimiter" ] [ text "/" ]
                        , div [ class "duration" ] duration
                        ]
                    ]
                , div [ class "row" ]
                    [ Pages.Build.View.viewError build
                    ]
                ]
            ]
    in
    div [ class "build-container", Util.testAttribute "build" ]
        [ div [ class "build", statusClass ] <|
            Pages.Build.View.buildStatusStyles markdown build.status build.number
        ]




{-| viewPipeline : takes model and renders collapsible template previews and the pipeline configuration file for the desired ref.
-}
viewPipeline : PartialModel a -> Html Msg
viewPipeline model =
    div [ class "pipeline" ]
        [ viewPipelineTemplates model.templates
        , viewPipelineConfiguration model
        ]


{-| viewPipelineTemplates : takes templates and renders a list above the pipeline configuration.
-}
viewPipelineTemplates : ( WebData Templates, Error ) -> Html Msg
viewPipelineTemplates templates =
    case templates of
        ( NotAsked, _ ) ->
            text ""

        ( Loading, _ ) ->
            Util.smallLoaderWithText "loading pipeline templates"

        ( Success t, _ ) ->
            viewTemplates t

        ( Failure _, err ) ->
            viewTemplatesError err


{-| viewTemplates : takes templates and renders a list of templates.

    Does not show if no templates are used in the pipeline.

-}
viewTemplates : Templates -> Html Msg
viewTemplates templates =
    if not <| Dict.isEmpty templates then
        templates
            |> Dict.toList
            |> List.map viewTemplate
            |> viewTemplatesDetails (class "-success")

    else
        text ""


{-| viewTemplates : renders an error from fetching templates.
-}
viewTemplatesError : Error -> Html Msg
viewTemplatesError err =
    [ text <| "There was a problem fetching templates for this pipeline configuration"
    , div [ Util.testAttribute "pipeline-templates-error" ] [ text err ]
    ]
        |> viewTemplatesDetails (class "-error")


{-| viewTemplatesDetails : takes templates content and wraps it in a details/summary.
-}
viewTemplatesDetails : Html.Attribute Msg -> List (Html Msg) -> Html Msg
viewTemplatesDetails cls content =
    Html.details
        [ class "details"
        , class "templates"
        , Html.Attributes.attribute "open" ""
        , Util.testAttribute "pipeline-templates"
        ]
        ([ Html.summary [ class "summary" ]
            [ div [] [ text "Templates" ]
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
         ]
            ++ [ div [ class "content", cls ] content ]
        )


{-| viewTemplate : takes template and renders view with name, source and HTML url.
-}
viewTemplate : ( String, Template ) -> Html msg
viewTemplate ( _, t ) =
    div [ class "template", Util.testAttribute <| "pipeline-template-" ++ t.name ]
        [ div [] [ strong [] [ text "Name:" ], strong [] [ text "Source:" ], strong [] [ text "Link:" ] ]
        , div []
            [ span [] [ text t.name ]
            , span [] [ text t.source ]
            , a
                [ Html.Attributes.target "_blank"
                , Html.Attributes.href t.link
                ]
                [ text t.link ]
            ]
        ]


{-| viewPipelineConfiguration : takes model and renders a wrapper view for a pipeline configuration if Success or Failure.
-}
viewPipelineConfiguration : PartialModel a -> Html Msg
viewPipelineConfiguration model =
    case model.pipeline.config of
        ( Loading, _ ) ->
            Util.smallLoaderWithText "loading pipeline configuration"

        ( NotAsked, _ ) ->
            text ""

        _ ->
            viewPipelineConfigurationResponse model


{-| viewPipelineConfiguration : takes model and renders view for a pipeline configuration.
-}
viewPipelineConfigurationResponse : PartialModel a -> Html Msg
viewPipelineConfigurationResponse model =
    -- TODO: modularize logs rendering
    div [ class "logs-container", class "-pipeline" ]
        [ case model.pipeline.config of
            ( Success config, _ ) ->
                viewPipelineConfigurationData model config

            ( Failure _, err ) ->
                viewPipelineConfigurationError model err

            _ ->
                text ""
        ]


{-| viewPipelineConfigurationData : takes model and config and renders view for a pipeline configuration's data.
-}
viewPipelineConfigurationData : PartialModel a -> PipelineConfig -> Html Msg
viewPipelineConfigurationData model config =
    wrapPipelineConfigurationContent model (class "") <|
        div [ class "logs", Util.testAttribute "pipeline-configuration-data" ] <|
            viewLines config model.pipeline.lineFocus model.shift


{-| viewPipelineConfigurationData : takes model and string and renders a pipeline configuration error.
-}
viewPipelineConfigurationError : PartialModel a -> Error -> Html Msg
viewPipelineConfigurationError model err =
    wrapPipelineConfigurationContent model (class "-error") <|
        div [ class "content", Util.testAttribute "pipeline-configuration-error" ]
            [ text <| "There was a problem fetching the pipeline configuration:", div [] [ text err ] ]


{-| wrapPipelineConfigurationContent : takes model, pipeline configuration and content and wraps it with a table, title and the template expansion header.
-}
wrapPipelineConfigurationContent : PartialModel a -> Html.Attribute Msg -> Html Msg -> Html Msg
wrapPipelineConfigurationContent model cls content =
    let
        body =
            [ div [ class "header" ]
                [ span [] [ text "Pipeline Configuration" ]
                ]
            , viewTemplatesExpansion model
            ]
                ++ [ content ]
    in
    Html.table
        [ class "logs-table"
        , cls
        ]
        body


{-| viewTemplatesExpansion : takes model and renders the config header button for expanding pipeline templates.
-}
viewTemplatesExpansion : PartialModel a -> Html Msg
viewTemplatesExpansion model =
    case model.templates of
        ( Success templates, _ ) ->
            if Dict.size templates > 0 then
                div [ class "expand-templates", Util.testAttribute "pipeline-templates-expand" ]
                    [ expandTemplatesToggleIcon model.pipeline
                    , expandTemplatesToggleButton model.pipeline
                    , expandTemplatesTip
                    ]

            else
                text ""

        ( Loading, _ ) ->
            text ""

        _ ->
            text ""


{-| expandTemplatesToggleIcon : takes pipeline and renders icon for toggling templates expansion.
-}
expandTemplatesToggleIcon : Pipeline -> Html Msg
expandTemplatesToggleIcon pipeline =
    let
        wrapExpandTemplatesIcon : Icon -> Html Msg
        wrapExpandTemplatesIcon i =
            div [ class "icon" ] [ i |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [] ]
    in
    if pipeline.expanding then
        Util.smallLoader

    else if pipeline.expanded then
        wrapExpandTemplatesIcon FeatherIcons.checkCircle

    else
        wrapExpandTemplatesIcon FeatherIcons.circle


{-| expandTemplatesToggleButton : takes pipeline and renders button that toggles templates expansion.
-}
expandTemplatesToggleButton : Pipeline -> Html Msg
expandTemplatesToggleButton pipeline =
    let
        { org, repo, ref } =
            pipeline

        action =
            if pipeline.expanded then
                GetPipelineConfig org repo ref True

            else
                ExpandPipelineConfig org repo ref True
    in
    button
        [ class "button"
        , class "-link"
        , Util.onClickPreventDefault <| action
        , Util.testAttribute "pipeline-templates-expand-toggle"
        ]
        [ if pipeline.expanded then
            text "revert template expansion"

          else
            text "expand templates"
        ]


{-| expandTemplatesTip : renders help tip that is displayed next to the expand templates button.
-}
expandTemplatesTip : Html Msg
expandTemplatesTip =
    small [ class "tip" ] [ text "note: yaml fields will be sorted alphabetically when expanding templates." ]



-- LINE FOCUS
-- TODO: modularize logs rendering


{-| viewLineS : takes pipeline configuration, line focus and shift key.

    returns a list of rendered data lines with focusable line numbers.

-}
viewLines : PipelineConfig -> LogFocus -> Bool -> List (Html Msg)
viewLines config lineFocus shift =
    config.data
        |> decodeAnsi
        |> Array.indexedMap
            (\idx line ->
                Just <|
                    viewLine "0"
                        (idx + 1)
                        (Just line)
                        "0"
                        lineFocus
                        shift
            )
        |> Array.toList
        |> Just
        |> Maybe.withDefault []
        |> List.filterMap identity


{-| viewLine : takes line and focus information and renders line number button and data.
-}
viewLine : ResourceID -> Int -> Maybe Ansi.Log.Line -> String -> LogFocus -> Bool -> Html Msg
viewLine id lineNumber line resource lineFocus shiftDown =
    tr
        [ Html.Attributes.id <|
            id
                ++ ":"
                ++ String.fromInt lineNumber
        , class "line"
        ]
        [ case line of
            Just l ->
                div
                    [ class "wrapper"
                    , Util.testAttribute <| String.join "-" [ "config", "line", resource, String.fromInt lineNumber ]
                    , class <| lineFocusStyles lineFocus lineNumber
                    ]
                    [ td []
                        [ lineFocusButton resource lineFocus lineNumber shiftDown ]
                    , td [ class "break-text", class "overflow-auto" ]
                        [ code [ Util.testAttribute <| String.join "-" [ "config", "data", resource, String.fromInt lineNumber ] ]
                            [ Ansi.Log.viewLine l
                            ]
                        ]
                    ]

            Nothing ->
                text ""
        ]


{-| lineFocusButton : renders button for focusing log line ranges.
-}
lineFocusButton : Resource -> LogFocus -> Int -> Bool -> Html Msg
lineFocusButton resource logFocus lineNumber shiftDown =
    button
        [ Util.onClickPreventDefault <|
            FocusLine <|
                lineNumber
        , Util.testAttribute <| String.join "-" [ "config", "line", "num", resource, String.fromInt lineNumber ]
        , Html.Attributes.id <| resourceAndLineToFocusId "config" resource lineNumber
        , class "line-number"
        , class "button"
        , class "-link"
        , attribute "aria-label" <| "focus resource " ++ resource
        ]
        [ span [] [ text <| String.fromInt lineNumber ] ]
