{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.Form exposing
    ( viewAddedParameters
    , viewDeployEnabled
    , viewHelp
    , viewParameterInput
    , viewSubmitButtons
    , viewValueInput
    )

import Html
    exposing
        ( Html
        , a
        , button
        , code
        , div
        , em
        , input
        , label
        , section
        , span
        , strong
        , text
        , textarea
        )
import Html.Attributes exposing (class, disabled, for, href, id, placeholder, rows, target, value, wrap)
import Html.Events exposing (onClick, onInput)
import Pages.Deployments.Model exposing (DeploymentForm, Model, Msg(..))
import RemoteData exposing (WebData)
import Util
import Vela exposing (KeyValuePair, Repo, Repository)


{-| viewAddedParameters : renders added parameters
-}
viewAddedParameters : List KeyValuePair -> List (Html Msg)
viewAddedParameters parameters =
    if List.length parameters > 0 then
        List.map addedParameter <| List.reverse parameters

    else
        noParameters


{-| noParameters : renders when no parameters have been added
-}
noParameters : List (Html Msg)
noParameters =
    [ div [ class "added-parameter" ]
        [ div [ class "name" ] [ code [] [ text "No Parameters defined" ] ]

        -- add button to match style
        , button
            [ class "button"
            , class "-outline"
            , class "visually-hidden"
            , disabled True
            ]
            [ text "remove"
            ]
        ]
    ]


{-| addedParameter : renders added parameter
-}
addedParameter : KeyValuePair -> Html Msg
addedParameter parameter =
    div [ class "added-parameter", class "chevron" ]
        [ div [ class "name" ] [ text (parameter.key ++ "=" ++ parameter.value) ]
        , button
            [ class "button"
            , class "-outline"
            , onClick <| RemoveParameter parameter
            ]
            [ text "remove"
            ]
        ]


{-| viewHelp : renders help msg pointing to Vela docs
-}
viewHelp : Html Msg
viewHelp =
    div [ class "help" ] [ text "Need help? Visit our ", a [ href deploymentDocsURL, target "_blank" ] [ text "docs" ], text "!" ]


{-| viewValueInput : renders value input box
-}
viewValueInput : String -> String -> String -> Html Msg
viewValueInput name val placeholder_ =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| name ] [ strong [] [ text name ] ]
        , textarea
            [ value val
            , onInput <| OnChangeStringField name
            , class "parameter-value"
            , class "form-control"
            , rows 2
            , wrap "soft"
            , placeholder placeholder_
            , id name
            ]
            []
        ]


{-| viewDeployEnabled : displays a message to enable Deploy webhook if it is not enabled
-}
viewDeployEnabled : WebData Repository -> Html Msg
viewDeployEnabled repo_settings =
    case repo_settings of
        RemoteData.Success repo ->
            if repo.allow_deploy then
                section []
                    []

            else
                section [ class "notice" ]
                    [ strong [] [ text "Deploy webhook for this repo must be enabled in settings" ]
                    ]

        _ ->
            section [] []


{-| viewParameterInput : renders parameters input box and parameters
-}
viewParameterInput : DeploymentForm -> Html Msg
viewParameterInput deployment =
    section [ class "parameter" ]
        [ div [ id "parameter-select", class "form-control", class "-stack" ]
            [ label [ for "parameter-select", class "form-label" ]
                [ strong [] [ text "Add Parameters" ]
                , span
                    [ class "field-description" ]
                    [ em [] [ text "(Optional)" ]
                    ]
                ]
            , input
                [ placeholder "Key"
                , class "parameter-input"
                , Util.testAttribute "parameter-key-input"
                , onInput <| OnChangeStringField "parameterInputKey"
                , value deployment.parameterInputKey
                ]
                []
            , input
                [ placeholder "Value"
                , class "parameter-input"
                , Util.testAttribute "parameter-value-input"
                , onInput <| OnChangeStringField "parameterInputValue"
                , value deployment.parameterInputValue
                ]
                []
            , button
                [ class "button"
                , Util.testAttribute "add-parameter-button"
                , class "-outline"
                , class "add-paramter"
                , onClick <| AddParameter <| deployment
                , disabled <| String.length deployment.parameterInputKey * String.length deployment.parameterInputValue == 0
                ]
                [ text "Add"
                ]
            ]
        , div [ class "parameters", Util.testAttribute "parameters-list" ] <| viewAddedParameters deployment.payload
        ]


viewSubmitButtons : Model msg -> Html Msg
viewSubmitButtons deploymentsModel =
    div [ class "buttons" ]
        [ viewUpdateButton deploymentsModel
        ]


viewUpdateButton : Model msg -> Html Msg
viewUpdateButton deploymentsModel =
    button
        [ class "button"
        , onClick <| Pages.Deployments.Model.AddDeployment
        ]
        [ text "Add Deployment" ]



-- HELPERS


deploymentDocsURL : String
deploymentDocsURL =
    "https://go-vela.github.io/docs/usage/deployments/"
