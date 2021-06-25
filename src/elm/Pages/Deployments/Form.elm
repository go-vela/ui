{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.Form exposing
    ( viewHelp
    , viewParameterInput
    , viewAddedParameters
    , viewTargetInput
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
import Html.Attributes
    exposing
        ( class
        , disabled
        , for
        , href
        , id
        , placeholder
        , rows
        , value
        , wrap
        )
import Html.Events exposing (onClick, onInput)
import Pages.Deployments.Model exposing (DeploymentForm, Model, Msg(..))
import Vela exposing (KeyValuePair)


{-| viewAddedImages : renders added images
-}
viewAddedParameters : List KeyValuePair -> List (Html Msg)
viewAddedParameters parameters =
    if List.length parameters > 0 then
        List.map addedParameter <| List.reverse parameters

    else
        noParameters


{-| noImages : renders when no images have been added
-}
noParameters : List (Html Msg)
noParameters =
    [ div [ class "added-image" ]
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


{-| addedImage : renders added image
-}
addedParameter : KeyValuePair -> Html Msg
addedParameter parameter =
    div [ class "added-image", class "chevron" ]
        [ div [ class "name" ] [ text (parameter.key ++ "=" ++ parameter.value)  ]
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
    div [ class "help" ] [ text "Need help? Visit our ", a [ href secretsDocsURL ] [ text "docs" ], text "!" ]


{-| viewNameInput : renders name input box
-}
viewTargetInput : String -> Bool -> Html Msg
viewTargetInput val disable =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| "secret-name" ] [ strong [] [ text "Target" ] ]
        , input
            [ disabled disable
            , value val
            , onInput <| OnChangeStringField "target"
            , class "secret-name"
            , placeholder "production"
            , id "secret-name"
            ]
            []
        ]


{-| viewValueInput : renders value input box
-}
viewValueInput : String -> String -> String -> Html Msg
viewValueInput name val placeholder_ =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| "secret-value" ] [ strong [] [ text name ] ]
        , textarea
            [ value val
            , onInput <| OnChangeStringField name
            , class "secret-value"
            , class "form-control"
            , rows 2
            , wrap "soft"
            , placeholder placeholder_
            , id "secret-value"
            ]
            []
        ]

{-| viewImagesInput : renders images input box and images
-}
viewParameterInput : DeploymentForm -> Html Msg
viewParameterInput deployment =
    section [ class "image" ]
        [ div [ id "images-select", class "form-control", class "-stack" ]
            [ label [ for "images-select", class "form-label" ]
                [ strong [] [ text "Add Parameters" ]
                , span
                    [ class "field-description" ]
                    [ em [] [ text "(Optional)" ]
                    ]
                ]
            , input
                [ placeholder "Key"
                , onInput <| OnChangeStringField "parameterInputKey"
                , value deployment.parameterInputKey
                ]
                []
            , input
                [ placeholder "Value"
                , onInput <| OnChangeStringField "parameterInputValue"
                , value deployment.parameterInputValue
                ]
                []
            , button
                [ class "button"
                , class "-outline"
                , class "add-image"
                , onClick <| AddParameter <| deployment
                , disabled <| String.length deployment.parameterInputKey * String.length deployment.parameterInputValue == 0
                ]
                [ text "Add"
                ]
            ]
        , div [ class "images" ] <| viewAddedParameters deployment.payload
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


{-| eventEnabled : takes event and returns if it is enabled
-}
eventEnabled : String -> List String -> Bool
eventEnabled event =
    List.member event


secretsDocsURL : String
secretsDocsURL =
    "https://go-vela.github.io/docs/concepts/pipeline/secrets/"
