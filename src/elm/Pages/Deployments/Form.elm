{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.Form exposing
    ( viewHelp
    , viewParameterInput
    , viewAddedParameters
    , viewNameInput
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
import Pages.RepoSettings exposing (checkbox)
import Pages.Deployments.Model exposing (DeploymentForm, KeyValuePair, Model, Msg(..))
import Util


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
        [ div [ class "name" ] [ text parameter.key ]
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
viewNameInput : String -> Bool -> Html Msg
viewNameInput val disable =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| "secret-name" ] [ strong [] [ text "Name" ] ]
        , input
            [ disabled disable
            , value val
            , onInput <|
                OnChangeStringField "name"
            , class "secret-name"
            , placeholder "Secret Name"
            , id "secret-name"
            ]
            []
        ]


{-| viewValueInput : renders value input box
-}
viewValueInput : String -> String -> Html Msg
viewValueInput val placeholder_ =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| "secret-value" ] [ strong [] [ text "Value" ] ]
        , textarea
            [ value val
            , onInput <| OnChangeStringField "value"
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
viewParameterInput : DeploymentForm -> KeyValuePair -> Html Msg
viewParameterInput deployment parameterInput =
    section [ class "image" ]
        [ div [ id "images-select", class "form-control", class "-stack" ]
            [ label [ for "images-select", class "form-label" ]
                [ strong [] [ text "Limit to Docker Images" ]
                , span
                    [ class "field-description" ]
                    [ em [] [ text "(Leave blank to enable this secret for all images)" ]
                    ]
                ]
            , input
                [ placeholder "Key"
                , onInput <| OnChangeStringField "keyInput"
                , value parameterInput.key
                ]
                []
            , input
                [ placeholder "Value"
                , onInput <| OnChangeStringField "valueInput"
                , value parameterInput.value
                ]
                []
            , button
                [ class "button"
                , class "-outline"
                , class "add-image"
                , onClick <| AddParameter <| parameterInput
                , disabled <| String.length parameterInput.key * String.length parameterInput.value == 0
                ]
                [ text "Add Paramters"
                ]
            ]
        , div [ class "images" ] <| viewAddedParameters deployment.payload
        ]


viewSubmitButtons : Model msg -> Html Msg
viewSubmitButtons secretsModel =
    div [ class "buttons" ]
        [ viewUpdateButton secretsModel
        ]


viewUpdateButton : Model msg -> Html Msg
viewUpdateButton deploymentsModel =
    button
        [ class "button"
        , onClick <| Pages.Deployments.Model.AddDeployment deploymentsModel.engine
        ]
        [ text "Update" ]


-- HELPERS


{-| eventEnabled : takes event and returns if it is enabled
-}
eventEnabled : String -> List String -> Bool
eventEnabled event =
    List.member event


secretsDocsURL : String
secretsDocsURL =
    "https://go-vela.github.io/docs/concepts/pipeline/secrets/"
