module Components.Builds exposing (view, viewHeader)

import Ansi
import Ansi.Log
import Components.Svgs as SvgBuilder exposing (buildStatusToIcon)
import DateFormat.Relative exposing (relativeTime)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , br
        , code
        , details
        , div
        , em
        , h1
        , input
        , label
        , li
        , ol
        , p
        , span
        , strong
        , summary
        , table
        , td
        , text
        , tr
        , ul
        )
import Html.Attributes
    exposing
        ( attribute
        , checked
        , class
        , classList
        , for
        , href
        , id
        , name
        , style
        , title
        , type_
        )
import Html.Events exposing (onClick)
import List.Extra
import Pages.Build.Model
    exposing
        ( Msgs
        )
import RemoteData exposing (WebData)
import Routes
import Shared
import String
import Time
import Utils.Errors as Errors
import Utils.Helpers as Util exposing (getNameFromRef)
import Vela
    exposing
        ( Build
        , BuildNumber
        , Org
        , Repo
        , Status(..)
        )



-- TYPES


type alias Msgs msg =
    { approveBuild : Org -> Repo -> BuildNumber -> msg
    , restartBuild : Org -> Repo -> BuildNumber -> msg
    , cancelBuild : Org -> Repo -> BuildNumber -> msg
    , showHideActionsMenus : Maybe Int -> Maybe Bool -> msg
    }


type alias Props msg =
    { msgs : Msgs msg
    , builds : WebData (List Vela.Build)
    , showActionsMenus : List Int
    , maybeEvent : Maybe String
    , showFullTimestamps : Bool
    , showActionsMenuBool : Bool
    }


view : Shared.Model -> Props msg -> Html msg
view shared props =
    let
        -- todo: handle query parameters ?event=push etc
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
                        [ h1 [] [ text "Your repository has been enabled!" ]
                        , p [] [ text "Builds will show up here once you have:" ]
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
                        (viewPreview shared props)
                        builds

        RemoteData.Loading ->
            Util.largeLoader

        RemoteData.NotAsked ->
            Util.largeLoader

        RemoteData.Failure _ ->
            Errors.viewResourceError { resourceLabel = "builds", testLabel = "builds" }


{-| viewPreview : renders single build item preview based on current application time
-}
viewPreview : Shared.Model -> Props msg -> Build -> Html msg
viewPreview shared props build =
    let
        isMenuOpen =
            List.member build.id props.showActionsMenus

        org =
            Maybe.withDefault "" <| List.head (List.drop 3 (String.split "/" build.link))

        repo =
            Maybe.withDefault "" <| List.head (List.drop 4 (String.split "/" build.link))

        buildMenuBaseClassList : Html.Attribute msg
        buildMenuBaseClassList =
            classList
                [ ( "details", True )
                , ( "-marker-right", True )
                , ( "-no-pad", True )
                , ( "build-toggle", True )
                ]

        buildMenuAttributeList : List (Html.Attribute msg)
        buildMenuAttributeList =
            Util.open (List.member build.id props.showActionsMenus) ++ [ id "build-actions" ]

        approveBuild : Html msg
        approveBuild =
            case build.status of
                Vela.PendingApproval ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"
                            , Util.onClickPreventDefault <| props.msgs.approveBuild org repo <| String.fromInt build.number
                            , Util.testAttribute "approve-build"
                            ]
                            [ text "Approve Build"
                            ]
                        ]

                _ ->
                    text ""

        restartBuild : Html msg
        restartBuild =
            case build.status of
                Vela.PendingApproval ->
                    text ""

                _ ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"
                            , Util.onClickPreventDefault <| props.msgs.restartBuild org repo <| String.fromInt build.number
                            , Util.testAttribute "restart-build"
                            ]
                            [ text "Restart Build"
                            ]
                        ]

        cancelBuild : Html msg
        cancelBuild =
            case build.status of
                Vela.Running ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"
                            , Util.onClickPreventDefault <| props.msgs.cancelBuild org repo <| String.fromInt build.number
                            , Util.testAttribute "cancel-build"
                            ]
                            [ text "Cancel Build"
                            ]
                        ]

                Vela.Pending ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"
                            , Util.onClickPreventDefault <| props.msgs.cancelBuild org repo <| String.fromInt build.number
                            , Util.testAttribute "cancel-build"
                            ]
                            [ text "Cancel Build"
                            ]
                        ]

                Vela.PendingApproval ->
                    li [ class "build-menu-item" ]
                        [ a
                            [ href "#"
                            , class "menu-item"
                            , Util.onClickPreventDefault <| props.msgs.cancelBuild org repo <| String.fromInt build.number
                            , Util.testAttribute "cancel-build"
                            ]
                            [ text "Cancel Build"
                            ]
                        ]

                _ ->
                    text ""

        actionsMenu =
            if props.showActionsMenuBool then
                details (buildMenuBaseClassList :: buildMenuAttributeList)
                    [ summary [ class "summary", Util.onClickPreventDefault (props.msgs.showHideActionsMenus (Just build.id) Nothing), Util.testAttribute "build-menu" ]
                        [ text "Actions"
                        , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml [ attribute "aria-label" "show build actions" ]
                        ]
                    , ul [ class "build-menu", attribute "aria-hidden" "true", attribute "role" "menu" ]
                        [ approveBuild
                        , restartBuild
                        , cancelBuild
                        ]
                    ]

            else
                div [] []

        repoLink =
            span []
                [ a [ Routes.href <| Routes.RepositoryBuilds org repo Nothing Nothing Nothing ] [ text repo ]
                , text ": "
                ]

        buildNumber =
            String.fromInt build.number

        status =
            [ buildStatusToIcon build.status ]

        commit =
            case build.event of
                "pull_request" ->
                    [ repoLink
                    , text <| String.replace "_" " " build.event
                    , text " "
                    , a [ href build.source ]
                        [ text "#"
                        , text (getNameFromRef build.ref)
                        ]
                    , text " ("
                    , a [ href build.source ] [ text <| Util.trimCommitHash build.commit ]
                    , text <| ")"
                    ]

                "tag" ->
                    [ repoLink
                    , text <| String.replace "_" " " build.event
                    , text " "
                    , a [ href build.source ] [ text (getNameFromRef build.ref) ]
                    , text " ("
                    , a [ href build.source ] [ text <| Util.trimCommitHash build.commit ]
                    , text <| ")"
                    ]

                "deployment" ->
                    [ repoLink
                    , text <| String.replace "_" " " build.event
                    , text " ("
                    , a [ href <| Util.buildRefURL build.clone build.commit ] [ text <| Util.trimCommitHash build.commit ]
                    , text <| ")"
                    ]

                _ ->
                    [ repoLink
                    , text <| String.replace "_" " " build.event
                    , text " ("
                    , a [ href build.source ] [ text <| Util.trimCommitHash build.commit ]
                    , text <| ")"
                    ]

        branch =
            [ a [ href <| Util.buildRefURL build.clone build.branch ] [ text build.branch ] ]

        sender =
            [ text build.sender ]

        message =
            [ text <| "- " ++ build.message ]

        buildId =
            [ a
                [ Util.testAttribute "build-number"
                , href build.link
                ]
                [ text <| "#" ++ buildNumber ]
            ]

        buildCreatedPosix =
            Time.millisToPosix <| Util.secondsToMillis build.created

        age =
            relativeTime shared.time <| buildCreatedPosix

        timestamp =
            Util.humanReadableDateTimeFormatter shared.zone buildCreatedPosix

        displayTime =
            if props.showFullTimestamps then
                [ text <| timestamp ++ " " ]

            else
                [ text age ]

        hoverTime =
            if props.showFullTimestamps then
                age

            else
                timestamp

        -- calculate build runtime
        runtime =
            Util.formatRunTime shared.time build.started build.finished

        -- mask completed/pending builds that have not finished
        duration =
            case build.status of
                Vela.Running ->
                    runtime

                _ ->
                    if build.started /= 0 && build.finished /= 0 then
                        runtime

                    else
                        "--:--"

        statusClass =
            statusToClass build.status
    in
    div [ class "build-container", Util.testAttribute "build" ]
        [ div [ class "build", statusClass ]
            [ div [ class "status", Util.testAttribute "build-status", statusClass ] status
            , div [ class "info" ]
                [ div [ class "row -left" ]
                    [ div [ class "id" ] buildId
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
                        [ div [ class "time-completed" ]
                            [ div [ class "age", title hoverTime ] displayTime
                            , span [ class "delimiter" ] [ text " /" ]
                            , div [ class "duration" ] [ text duration ]
                            ]
                        , actionsMenu
                        ]
                    ]
                , div [ class "row" ]
                    [ viewError build
                    ]
                ]
            , buildAnimation build.status build.number
            ]
        ]


{-| viewError : checks for build error and renders message
-}
viewError : Build -> Html msg
viewError build =
    case build.status of
        Vela.Error ->
            div [ class "error", Util.testAttribute "build-error" ]
                [ span [ class "label" ] [ text "error:" ]
                , span [ class "message" ]
                    [ text <|
                        if String.isEmpty build.error then
                            "no error msg"

                        else
                            build.error
                    ]
                ]

        Vela.Canceled ->
            let
                defaultLabel =
                    text "canceled:"

                ( label, message ) =
                    if String.isEmpty build.error then
                        ( defaultLabel, text "no error message" )

                    else
                        let
                            tgtBuild =
                                String.split " " build.error
                                    |> List.Extra.last
                                    |> Maybe.withDefault ""
                        in
                        -- check if the last part of the error message was a number
                        -- to handle auto canceled build messages which come in the
                        -- form of "build was auto canceled in favor of build 42"
                        case String.toInt tgtBuild of
                            -- not an auto cancel message, use the returned error msg
                            Nothing ->
                                ( defaultLabel, text build.error )

                            -- some special treatment to turn build number
                            -- into a link to the respective build
                            Just _ ->
                                let
                                    linkList =
                                        String.split "/" build.link
                                            |> List.reverse

                                    newLink =
                                        linkList
                                            |> List.Extra.setAt 0 tgtBuild
                                            |> List.reverse
                                            |> String.join "/"

                                    msg =
                                        String.replace tgtBuild "" build.error
                                in
                                ( text "auto canceled:"
                                , span [] [ text msg, a [ href newLink, Util.testAttribute "new-build-link" ] [ text ("#" ++ tgtBuild) ] ]
                                )
            in
            div [ class "error", Util.testAttribute "build-error" ]
                [ span [ class "label" ] [ label ]
                , span [ class "message" ] [ message ]
                ]

        _ ->
            div [ class "error hidden-spacer", Util.testAttribute "build-spacer" ]
                [ span [ class "label" ] [ text "No Errors" ]
                , span [ class "message" ]
                    [ text "This div is hidden to occupy space for a consistent experience" ]
                ]


{-| statusToClass : takes build status and returns css class
-}
statusToClass : Status -> Html.Attribute msg
statusToClass status =
    case status of
        Vela.Pending ->
            class "-pending"

        Vela.PendingApproval ->
            class "-pending"

        Vela.Running ->
            class "-running"

        Vela.Success ->
            class "-success"

        Vela.Failure ->
            class "-failure"

        Vela.Killed ->
            class "-failure"

        Vela.Canceled ->
            class "-canceled"

        Vela.Error ->
            class "-error"


{-| buildAnimation : takes build info and returns div containing styled flair based on running status
-}
buildAnimation : Status -> Int -> Html msg
buildAnimation buildStatus buildNumber =
    case buildStatus of
        Vela.Running ->
            div [ class "build-animation" ] <| topParticles buildNumber ++ bottomParticles buildNumber

        _ ->
            div [ class "build-animation", class "-not-running", statusToClass buildStatus ] []


{-| topParticles : returns an svg frame to parallax scroll on a running build, set to the top of the build
-}
topParticles : Int -> List (Html msg)
topParticles buildNumber =
    let
        -- Use the build number to dynamically set the dash particles, this way builds wont always have the same particle effects
        dashes =
            topBuildNumberDashes buildNumber

        y =
            "0%"
    in
    [ SvgBuilder.buildStatusAnimation "" y [ "-frame-0", "-top", "-cover" ]
    , SvgBuilder.buildStatusAnimation "none" y [ "-frame-0", "-top", "-start" ]
    , SvgBuilder.buildStatusAnimation dashes y [ "-frame-1", "-top", "-running" ]
    , SvgBuilder.buildStatusAnimation dashes y [ "-frame-2", "-top", "-running" ]
    ]


{-| bottomParticles : returns an svg frame to parallax scroll on a running build, set to the bottom of the build
-}
bottomParticles : Int -> List (Html msg)
bottomParticles buildNumber =
    let
        -- Use the build number to dynamically set the dash particles, this way builds wont always have the same particle effects
        dashes =
            bottomBuildNumberDashes buildNumber

        y =
            "100%"
    in
    [ SvgBuilder.buildStatusAnimation "" y [ "-frame-0", "-bottom", "-cover" ]
    , SvgBuilder.buildStatusAnimation "none" y [ "-frame-0", "-bottom", "-start" ]
    , SvgBuilder.buildStatusAnimation dashes y [ "-frame-1", "-bottom", "-running" ]
    , SvgBuilder.buildStatusAnimation dashes y [ "-frame-2", "-bottom", "-running" ]
    ]


{-| topBuildNumberDashes : returns a different particle effect based on a module of the build number
-}
topBuildNumberDashes : Int -> String
topBuildNumberDashes buildNumber =
    case modBy 3 buildNumber of
        1 ->
            "-animation-dashes-1"

        2 ->
            "-animation-dashes-2"

        _ ->
            "-animation-dashes-3"


{-| bottomBuildNumberDashes : returns a different particle effect based on a module of the build number
-}
bottomBuildNumberDashes : Int -> String
bottomBuildNumberDashes buildNumber =
    case modBy 3 buildNumber of
        1 ->
            "-animation-dashes-3"

        2 ->
            "-animation-dashes-1"

        _ ->
            "-animation-dashes-2"


{-| styleAttributesAnsi : takes Ansi.Log.Style and renders it into ANSI style Html attributes
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been pulled in unmodified because elm-ansi does not expose it
-}
styleAttributesAnsi : Ansi.Log.Style -> List (Html.Attribute msg)
styleAttributesAnsi logStyle =
    [ style "font-weight"
        (if logStyle.bold then
            "bold"

         else
            "normal"
        )
    , style "text-decoration"
        (if logStyle.underline then
            "underline"

         else
            "none"
        )
    , style "font-style"
        (if logStyle.italic then
            "italic"

         else
            "normal"
        )
    , let
        fgClasses =
            colorClassesAnsi "-fg"
                logStyle.bold
                (if not logStyle.inverted then
                    logStyle.foreground

                 else
                    logStyle.background
                )

        bgClasses =
            colorClassesAnsi "-bg"
                logStyle.bold
                (if not logStyle.inverted then
                    logStyle.background

                 else
                    logStyle.foreground
                )

        fgbgClasses =
            List.map (\a -> (\b c -> ( b, c )) a True) (fgClasses ++ bgClasses)

        ansiClasses =
            [ ( "ansi-blink", logStyle.blink )
            , ( "ansi-faint", logStyle.faint )
            , ( "ansi-Fraktur", logStyle.fraktur )
            , ( "ansi-framed", logStyle.framed )
            ]
      in
      classList (fgbgClasses ++ ansiClasses)
    ]


{-| colorClassesAnsi : takes style parameters and renders it into ANSI styled color classes that can be used with the Html style attribute
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been pulled unmodified in because elm-ansi does not expose it
-}
colorClassesAnsi : String -> Bool -> Maybe Ansi.Color -> List String
colorClassesAnsi suffix bold mc =
    let
        brightPrefix =
            "ansi-bright-"

        prefix =
            if bold then
                brightPrefix

            else
                "ansi-"
    in
    case mc of
        Nothing ->
            if bold then
                [ "ansi-bold" ]

            else
                []

        Just Ansi.Black ->
            [ prefix ++ "black" ++ suffix ]

        Just Ansi.Red ->
            [ prefix ++ "red" ++ suffix ]

        Just Ansi.Green ->
            [ prefix ++ "green" ++ suffix ]

        Just Ansi.Yellow ->
            [ prefix ++ "yellow" ++ suffix ]

        Just Ansi.Blue ->
            [ prefix ++ "blue" ++ suffix ]

        Just Ansi.Magenta ->
            [ prefix ++ "magenta" ++ suffix ]

        Just Ansi.Cyan ->
            [ prefix ++ "cyan" ++ suffix ]

        Just Ansi.White ->
            [ prefix ++ "white" ++ suffix ]

        Just Ansi.BrightBlack ->
            [ brightPrefix ++ "black" ++ suffix ]

        Just Ansi.BrightRed ->
            [ brightPrefix ++ "red" ++ suffix ]

        Just Ansi.BrightGreen ->
            [ brightPrefix ++ "green" ++ suffix ]

        Just Ansi.BrightYellow ->
            [ brightPrefix ++ "yellow" ++ suffix ]

        Just Ansi.BrightBlue ->
            [ brightPrefix ++ "blue" ++ suffix ]

        Just Ansi.BrightMagenta ->
            [ brightPrefix ++ "magenta" ++ suffix ]

        Just Ansi.BrightCyan ->
            [ brightPrefix ++ "cyan" ++ suffix ]

        Just Ansi.BrightWhite ->
            [ brightPrefix ++ "white" ++ suffix ]


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
