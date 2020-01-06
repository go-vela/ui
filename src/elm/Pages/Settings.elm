{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Settings exposing
    ( access
    , alert
    , checkbox
    , enableCurrentRepo
    , enableRepo
    , enableable
    , events
    , radio
    , timeout
    , timeoutInput
    , timeoutWarning
    , validAccessUpdate
    , validEventsUpdate
    , view
    )

import Dict exposing (Dict)
import Html
    exposing
        ( Html
        , button
        , div
        , em
        , input
        , label
        , li
        , p
        , span
        , text
        )
import Html.Attributes
    exposing
        ( checked
        , class
        , classList
        , disabled
        , for
        , id
        , type_
        , value
        )
import Html.Events exposing (onCheck, onClick, onInput)
import List.Extra
import RemoteData exposing (RemoteData(..), WebData)
import SvgBuilder
import Util
import Vela
    exposing
        ( DisableRepo
        , EnableRepo
        , Enabled
        , Field
        , Repositories
        , Repository
        , SourceRepositories
        , UpdateRepositoryPayload
        )



-- TYPES


{-| CheckboxUpdate : type that takes Msg for forwarding checkbox input callback to Main.elm
-}
type alias CheckboxUpdate msg =
    String -> String -> String -> (Bool -> msg)


{-| RadioUpdate : type that takes Msg for forwarding radio input callback to Main.elm
-}
type alias RadioUpdate msg =
    String -> String -> String -> (String -> msg)


{-| NumberInputChange : type that takes Msg for forwarding number input callback to Main.elm
-}
type alias NumberInputChange msg =
    String -> String -> String -> Int -> msg



-- VIEW


{-| view : takes model, org and repo and renders page for updating repo settings
-}
view : WebData Repository -> Maybe Int -> CheckboxUpdate msg -> RadioUpdate msg -> NumberInputChange msg -> (String -> msg) -> DisableRepo msg -> EnableRepo msg -> Html msg
view repo inTimeout eventsUpdate accessUpdate timeoutUpdate inTimeoutChange disableRepoMsg enableRepoMsg =
    let
        loading =
            div []
                [ Util.largeLoader
                ]
    in
    case repo of
        Success repo_ ->
            div [ class "repo-settings", Util.testAttribute "repo-settings" ]
                [ div [ class "row" ] [ events repo_ eventsUpdate, access repo_ accessUpdate ]
                , div [ class "row" ] [ timeout inTimeout repo_ timeoutUpdate inTimeoutChange, enable disableRepoMsg enableRepoMsg repo_ ]
                ]

        Loading ->
            loading

        NotAsked ->
            loading

        Failure _ ->
            div []
                [ p []
                    [ text <|
                        "There was an error fetching your repo settings... Click Refresh or try again later!"
                    ]
                ]


{-| access : takes model and repo and renders the settings category for updating repo access
-}
access : Repository -> RadioUpdate msg -> Html msg
access repo msg =
    div [ class "category", Util.testAttribute "repo-settings-access" ]
        [ div [ class "header" ] [ span [ class "text" ] [ text "Access" ] ]
        , div [ class "description" ] [ text "Change who can access build information." ]
        , div [ class "inputs", class "radios" ]
            [ radio repo.visibility "private" "Private" <| msg repo.org repo.name "visibility" "private"
            , radio repo.visibility "public" "Any" <| msg repo.org repo.name "visibility" "public"
            ]
        ]


{-| events : takes model and repo and renders the settings category for updating repo webhook events
-}
events : Repository -> CheckboxUpdate msg -> Html msg
events repo msg =
    div [ class "category", Util.testAttribute "repo-settings-events" ]
        [ div [ class "header" ] [ span [ class "text" ] [ text "Webhook Events" ] ]
        , div [ class "description" ] [ text "Control which events on Git will trigger Vela pipelines." ]
        , div [ class "description" ] [ em [] [ text "Active repositories must have at least one event enabled." ] ]
        , div [ class "inputs" ]
            [ checkbox "Push"
                "allow_push"
                repo.allow_push
              <|
                msg repo.org repo.name "allow_push"
            , checkbox "Pull Request"
                "allow_pull"
                repo.allow_pull
              <|
                msg repo.org repo.name "allow_pull"
            , checkbox "Deploy"
                "allow_deploy"
                repo.allow_deploy
              <|
                msg repo.org repo.name "allow_deploy"
            , checkbox "Tag"
                "allow_tag"
                repo.allow_tag
              <|
                msg repo.org repo.name "allow_tag"
            ]
        ]


{-| timeout : takes model and repo and renders the settings category for updating repo build timeout
-}
timeout : Maybe Int -> Repository -> NumberInputChange msg -> (String -> msg) -> Html msg
timeout inTimeout repo clickMsg inputMsg =
    div [ class "category", Util.testAttribute "repo-settings-timeout" ]
        [ div [ class "header" ] [ span [ class "text" ] [ text "Build Timeout" ] ]
        , div [ class "description" ] [ text "Builds that reach this timeout setting will be stopped." ]
        , timeoutInput repo
            inTimeout
            inputMsg
          <|
            clickMsg repo.org repo.name "timeout" <|
                Maybe.withDefault 0 inTimeout
        , timeoutWarning inTimeout
        ]


{-| checkbox : takes field name, id, state and click action, and renders an input checkbox.
-}
checkbox : String -> Field -> Bool -> (Bool -> msg) -> Html msg
checkbox name field state msg =
    div [ class "checkbox", Util.testAttribute <| "repo-checkbox-" ++ field ]
        [ SvgBuilder.checkbox state
        , input
            [ type_ "checkbox"
            , id <| "checkbox-" ++ field
            , checked state
            , onCheck msg
            ]
            []
        , label [ for <| "checkbox-" ++ field ] [ span [ class "label" ] [ text name ] ]
        ]


{-| radio : takes current value, field id, title for label, and click action and renders an input radio.
-}
radio : String -> String -> Field -> msg -> Html msg
radio value field title msg =
    div [ class "checkbox", class "radio", Util.testAttribute <| "repo-radio-" ++ field ]
        [ SvgBuilder.radio (value == field)
        , input
            [ type_ "radio"
            , id <| "radio-" ++ field
            , checked (value == field)
            , onClick msg
            ]
            []
        , label [ for <| "radio-" ++ field ] [ span [ class "label" ] [ text title, updateTip field ] ]
        ]


{-| timeoutInput : takes repo, user input, and button action and renders the text input for updating build timeout.
-}
timeoutInput : Repository -> Maybe Int -> (String -> msg) -> msg -> Html msg
timeoutInput repo inTimeout inputMsg clickMsg =
    div [ class "inputs", class "repo-timeout", Util.testAttribute "repo-timeout" ]
        [ input
            [ id <| "repo-timeout"
            , onInput inputMsg
            , type_ "number"
            , Html.Attributes.min "30"
            , Html.Attributes.max "90"
            , value <| String.fromInt <| Maybe.withDefault repo.timeout inTimeout
            ]
            []
        , label [ for "repo-timeout" ] [ span [ class "label" ] [ text "minutes" ] ]
        , updateTimeout inTimeout
            repo.timeout
            clickMsg
        ]


{-| updateTimeout : takes maybe int of user entered timeout and current repo timeout and renders the button to submit the update.
-}
updateTimeout : Maybe Int -> Int -> msg -> Html msg
updateTimeout inTimeout repoTimeout msg =
    case inTimeout of
        Just _ ->
            button
                [ classList
                    [ ( "-btn", True )
                    , ( "-inverted", True )
                    , ( "-repo-timeout", True )
                    ]
                , onClick msg
                , disabled <| not <| validTimeout inTimeout <| Just repoTimeout
                ]
                [ text "update" ]

        Nothing ->
            text ""


{-| timeoutWarning : takes maybe string of user entered timeout and renders a disclaimer on updating the build timeout.
-}
timeoutWarning : Maybe Int -> Html msg
timeoutWarning inTimeout =
    case inTimeout of
        Just _ ->
            div [ class "timeout-help" ]
                [ text "Disclaimer: if you are experiencing build timeouts, it is highly recommended to optimize your pipeline before altering this value. Timeouts must also lie between 30 and 90 minutes."
                ]

        Nothing ->
            text ""


{-| enable : takes enable actions and repo and returns view of the repo enable admin action.
-}
enable : DisableRepo msg -> EnableRepo msg -> Repository -> Html msg
enable disableRepoMsg enableRepoMsg repo =
    let
        enabledDetails =
            if disableable repo.enabling then
                ( "Disable Repository", "This will delete the Vela webhook from this repository." )

            else
                ( "Enable Repository", "This will create the Vela webhook for this repository." )
    in
    div [ class "category", Util.testAttribute "repo-settings-timeout" ]
        [ div [ class "header" ] [ span [ class "text" ] [ text "Admin" ] ]
        , div [ class "description" ] [ text "These configurations require admin privileges." ]
        , li [ class "enable-container" ]
            [ div [ class "enable-column-a" ]
                [ span [ class "enable-btn-label-a" ] [ text <| Tuple.first enabledDetails ]
                , em [ class "enable-btn-label-b" ] [ text <| Tuple.second enabledDetails ]
                ]
            , div [ class "enable-column-b" ] [ div [] [ enabledButton disableRepoMsg enableRepoMsg repo ] ]
            ]
        ]


{-| enabledButton : takes enable actions and repo and returns view of the repo enable button.
-}
enabledButton : DisableRepo msg -> EnableRepo msg -> Repository -> Html msg
enabledButton disableRepoMsg enableRepoMsg repo =
    let
        baseClasses =
            classList [ ( "-btn", True ), ( "-inverted", True ), ( "-view", True ), ( "repo-disable", True ) ]

        inProgressClasses =
            classList [ ( "repo-enable", True ), ( "repo-disable-disabling", True ), ( "repo-disable", True ) ]

        baseTestAttribute =
            Util.testAttribute "repo-disable"
    in
    case repo.enabling of
        Vela.NotAsked_ ->
            button
                [ baseClasses
                , baseTestAttribute
                , disabled True
                , onClick <| disableRepoMsg repo
                ]
                [ text "Error" ]

        Vela.Enabled ->
            button
                [ baseClasses
                , baseTestAttribute
                , onClick <| disableRepoMsg repo
                ]
                [ text "Disable" ]

        Vela.Disabled ->
            button
                [ baseClasses
                , Util.testAttribute "repo-enable"
                , onClick <| enableRepoMsg repo
                ]
                [ text "Enable" ]

        Vela.ConfirmDisable ->
            button
                [ baseClasses
                , baseTestAttribute
                , class "repo-disable-confirm"
                , onClick <| disableRepoMsg repo
                ]
                [ text "Really Disable?" ]

        Vela.Disabling ->
            div [ inProgressClasses, Util.testAttribute "repo-disabling" ]
                [ span [ class "repo-disable-disabling-text" ]
                    [ text "Disabling" ]
                , span [ class "loading-ellipsis" ] []
                ]

        Vela.Enabling ->
            div [ inProgressClasses, Util.testAttribute "repo-enabling" ]
                [ span [ class "repo-disable-disabling-text" ]
                    [ text "Enabling" ]
                , span [ class "loading-ellipsis" ] []
                ]



-- HELPERS


{-| alert : takes update field and updated repo and returns how to alert the user.
-}
alert : Field -> Repository -> String
alert field repo =
    let
        prefix =
            msgPrefix field

        suffix =
            msgSuffix field repo
    in
    String.replace "$" repo.full_name <| prefix ++ suffix


{-| validTimeout : takes maybe string of user entered timeout and returns whether or not it is a valid update.
-}
validTimeout : Maybe Int -> Maybe Int -> Bool
validTimeout inTimeout repoTimeout =
    case inTimeout of
        Just t ->
            if t >= 30 && t <= 90 then
                case repoTimeout of
                    Just ti ->
                        if t /= ti then
                            True

                        else
                            False

                    Nothing ->
                        True

            else
                False

        Nothing ->
            True


{-| validAccessUpdate : takes model webdata repo and repo visibility update and determines if an update is necessary
-}
validAccessUpdate : WebData Repository -> UpdateRepositoryPayload -> Bool
validAccessUpdate originalRepo repoUpdate =
    case originalRepo of
        RemoteData.Success repo ->
            case repoUpdate.visibility of
                Just visibility ->
                    if repo.visibility /= visibility then
                        True

                    else
                        False

                Nothing ->
                    False

        _ ->
            False


{-| validEventsUpdate : takes model webdata repo and repo events update and determines if an update is necessary
-}
validEventsUpdate : WebData Repository -> UpdateRepositoryPayload -> Bool
validEventsUpdate originalRepo repoUpdate =
    case originalRepo of
        RemoteData.Success repo ->
            Maybe.withDefault repo.allow_push repoUpdate.allow_push
                || Maybe.withDefault repo.allow_pull repoUpdate.allow_pull
                || Maybe.withDefault repo.allow_deploy repoUpdate.allow_deploy
                || Maybe.withDefault repo.allow_tag repoUpdate.allow_tag

        _ ->
            False


{-| updateTip : takes field and returns the tip to display after the label.
-}
updateTip : Field -> Html msg
updateTip field =
    span [ class "field-info" ] <|
        case field of
            "private" ->
                [ text "(restricted to those with repository access)" ]

            "public" ->
                [ text "(anyone with access to this Vela instance)" ]

            _ ->
                []


{-| msgPrefix : takes update field and returns alert prefix.
-}
msgPrefix : Field -> String
msgPrefix field =
    case field of
        "private" ->
            "$ privacy set to "

        "trusted" ->
            "$ set to "

        "visibility" ->
            "$ visibility set to "

        "allow_pull" ->
            "Pull events for $ "

        "allow_push" ->
            "Push events for $ "

        "allow_deploy" ->
            "Deploy events for $ "

        "allow_tag" ->
            "Tag events for $ "

        "timeout" ->
            "Build timeout for $ "

        _ ->
            "Unrecognized update made to $."


{-| msgSuffix : takes update field and returns alert suffix.
-}
msgSuffix : Field -> Repository -> String
msgSuffix field repo =
    case field of
        "private" ->
            toggleText "private" repo.private

        "trusted" ->
            toggleText "trusted" repo.trusted

        "visibility" ->
            repo.visibility ++ "."

        "allow_pull" ->
            toggleText "allow_pull" repo.allow_pull

        "allow_push" ->
            toggleText "allow_push" repo.allow_push

        "allow_deploy" ->
            toggleText "allow_deploy" repo.allow_deploy

        "allow_tag" ->
            toggleText "allow_tag" repo.allow_tag

        "timeout" ->
            "set to " ++ String.fromInt repo.timeout ++ " minute(s)."

        _ ->
            ""


{-| toggleText : takes toggle field id and value and returns the text to display when toggling.
-}
toggleText : Field -> Bool -> String
toggleText field value =
    let
        ( enabled, disabled ) =
            case field of
                "private" ->
                    ( "private.", "any." )

                "trusted" ->
                    ( "trusted.", "untrusted." )

                _ ->
                    ( "enabled.", "disabled." )
    in
    if value then
        enabled

    else
        disabled


{-| disableable : takes enabled status and returns if the repo is disableable.
-}
disableable : Enabled -> Bool
disableable status =
    case status of
        Vela.Enabled ->
            True

        Vela.ConfirmDisable ->
            True

        Vela.Disabling ->
            True

        Vela.Enabling ->
            False

        Vela.Disabled ->
            False

        Vela.NotAsked_ ->
            False


{-| enableable : takes enabled status and returns if the repo is enableable.
-}
enableable : Enabled -> Bool
enableable status =
    not <| disableable status


{-| enableCurrentRepo : takes repo, enabled status and repos and sets enabled status of the specified repo
-}
enableCurrentRepo : Repository -> Enabled -> Repositories -> WebData Repositories
enableCurrentRepo repo status repos =
    RemoteData.succeed
        (List.Extra.updateIf (\currentRepo -> currentRepo.name == repo.name)
            (\currentRepo -> { currentRepo | enabling = status })
            repos
        )


{-| enableRepo : takes repo, enabled status and source repos and sets enabled status of the specified repo
-}
enableRepo : Repository -> WebData Bool -> WebData SourceRepositories -> WebData SourceRepositories
enableRepo repo status sourceRepos =
    case sourceRepos of
        Success repos ->
            case Dict.get repo.org repos of
                Just orgRepos ->
                    RemoteData.succeed <| enableRepoDict repo status repos orgRepos

                _ ->
                    sourceRepos

        _ ->
            sourceRepos


{-| enableRepoDict : update the dictionary containing org source repo lists
-}
enableRepoDict : Repository -> WebData Bool -> Dict String Repositories -> Repositories -> Dict String Repositories
enableRepoDict repo status repos orgRepos =
    Dict.update repo.org (\_ -> Just <| enableRepoList repo status orgRepos) repos


{-| enableRepoList : list map for updating single repo status by repo name
-}
enableRepoList : Repository -> WebData Bool -> Repositories -> Repositories
enableRepoList repo status orgRepos =
    List.map
        (\sourceRepo ->
            if sourceRepo.name == repo.name then
                { sourceRepo | enabled = status }

            else
                sourceRepo
        )
        orgRepos
