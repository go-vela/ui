{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Settings exposing
    ( buildTimeoutValue
    , repoUpdatedAlert
    , updateRepoCheckbox
    , updateRepoRadio
    )

import Html
    exposing
        ( Html
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
        )
import Html.Events
    exposing
        ( onClick
        )
import SvgBuilder
import Util
import Vela exposing (Field, Repository)



-- VIEW


updateRepoCheckbox : String -> Field -> Bool -> msg -> Html msg
updateRepoCheckbox name field value action =
    div [ class "checkbox" ]
        [ SvgBuilder.checkbox value |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] []
        , input
            [ Util.testAttribute <| "repo-checkbox-" ++ field
            , id <| "checkbox-" ++ field
            , checked value
            , onClick action
            , type_ "checkbox"
            ]
            []
        , label [ for <| "checkbox-" ++ field ] [ span [ class "label" ] [ text name ] ]
        ]


updateRepoRadio : String -> String -> Field -> msg -> Html msg
updateRepoRadio value field title action =
    div [ class "checkbox", class "radio" ]
        [ SvgBuilder.radio (value == field) |> SvgBuilder.toHtml [ attribute "aria-hidden" "true" ] []
        , input
            [ type_ "radio"
            , id <| "radio-" ++ field
            , checked (value == field)
            , onClick action
            , Util.testAttribute <| "repo-radio-any"
            ]
            []
        , label [ for <| "radio-" ++ field ] [ span [ class "label" ] [ text title, updateRepoFieldTip field ] ]
        ]



-- HELPERS


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
