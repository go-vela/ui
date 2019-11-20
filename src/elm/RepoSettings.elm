{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module RepoSettings exposing
    ( buildTimeoutUpdateButton
    , buildTimeoutValue
    , repoUpdatedAlert
    , updateRepoCheckbox
    , updateRepoRadio
    , updateRepoTimeoutInput
    )

import Html
    exposing
        ( Html
        , button
        , div
        , input
        , label
        , span
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , checked
        , class
        , for
        , id
        , type_
        , value
        )
import Html.Events exposing (onCheck, onClick, onInput)
import SvgBuilder
import Util
import Vela exposing (Field, Repository)



-- VIEW


updateRepoCheckbox : String -> Field -> Bool -> (Bool -> msg) -> Html msg
updateRepoCheckbox name field state action =
    div [ class "checkbox", Util.testAttribute <| "repo-checkbox-" ++ field ]
        [ SvgBuilder.checkbox state |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] []
        , input
            [ type_ "checkbox"
            , id <| "checkbox-" ++ field

            -- , value <| checkedValue state
            , checked state
            , onCheck action
            ]
            []
        , label [ for <| "checkbox-" ++ field ] [ span [ class "label" ] [ text name ] ]
        ]


updateRepoRadio : String -> String -> Field -> msg -> Html msg
updateRepoRadio value field title action =
    div [ class "checkbox", class "radio", Util.testAttribute <| "repo-radio-" ++ field ]
        [ SvgBuilder.radio (value == field) |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] []
        , input
            [ type_ "radio"
            , id <| "radio-" ++ field
            , checked (value == field)
            , onClick action
            ]
            []
        , label [ for <| "radio-" ++ field ] [ span [ class "label" ] [ text title, updateRepoFieldTip field ] ]
        ]


updateRepoTimeoutInput : Repository -> Maybe String -> (String -> msg) -> msg -> Html msg
updateRepoTimeoutInput repo inTimeout inputAction buttonAction =
    div [ class "inputs", class "repo-timeout", Util.testAttribute "repo-timeout" ]
        [ input
            [ id <| "repo-timeout"
            , value <| buildTimeoutValue inTimeout repo.timeout
            , onInput inputAction
            , type_ "text"
            ]
            []
        , label [ for "repo-timeout" ] [ span [ class "label" ] [ text "minutes" ] ]
        , buildTimeoutUpdateButton (Maybe.withDefault "" inTimeout)
            repo.timeout
            buttonAction
        ]


buildTimeoutUpdateButton : String -> Int -> msg -> Html msg
buildTimeoutUpdateButton inTimeout repoTimeout m =
    if String.isEmpty inTimeout then
        text ""

    else if inTimeout /= String.fromInt repoTimeout then
        button
            [ class "-btn"
            , class "-solid"
            , class "-repo-timeout"
            , onClick m
            ]
            [ text "update" ]

    else
        text ""



-- HELPERS


checkedValue : Bool -> String
checkedValue checked =
    if checked then
        "on"

    else
        "off"


buildTimeoutValue : Maybe String -> Int -> String
buildTimeoutValue inTimeout repoTimeout =
    Maybe.withDefault (String.fromInt repoTimeout) inTimeout


updateRepoFieldTip : Field -> Html msg
updateRepoFieldTip field =
    span [ class "field-info" ] <|
        case field of
            "private" ->
                [ text "(restricted to those with repository access)" ]

            "public" ->
                [ text "(anyone with access to this Vela instance)" ]

            _ ->
                []


{-| repoUpdatedAlert : takes update field and updated repo and returns how to alert the user.
-}
repoUpdatedAlert : Field -> Repository -> String
repoUpdatedAlert field repo =
    let
        prefix =
            msgPrefix field

        suffix =
            msgSuffix field repo
    in
    String.replace "$" repo.full_name <| prefix ++ suffix


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


{-| msgSuffix : takes bool value and returns disabled/enabled.
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
