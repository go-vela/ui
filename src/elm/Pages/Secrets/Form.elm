{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.Form exposing
    ( viewAddedImages
    , viewEventsSelect
    , viewHelp
    , viewImagesInput
    , viewNameInput
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
        , h4
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
        ( checked
        , class
        , disabled
        , for
        , href
        , id
        , placeholder
        , type_
        , value
        )
import Html.Events exposing (onClick, onInput)
import Pages.RepoSettings exposing (checkbox)
import Pages.Secrets.Model exposing (Msg(..), SecretForm)
import Util
import Vela exposing (Field)


{-| viewAddedImages : renders added images
-}
viewAddedImages : List String -> List (Html Msg)
viewAddedImages images =
    if List.length images > 0 then
        List.map addedImage <| List.reverse images

    else
        noImages


{-| noImages : renders when no images have been added
-}
noImages : List (Html Msg)
noImages =
    [ div [ class "added-image" ]
        [ div [ class "name" ] [ code [] [ text "enabled for all images" ] ]

        -- add button to match style
        , button
            [ class "button"
            , class "-outline"
            , class "-hide"
            , disabled True
            ]
            [ text "remove"
            ]
        ]
    ]


{-| addedImage : renders added image
-}
addedImage : String -> Html Msg
addedImage image =
    div [ class "added-image", class "chevron" ]
        [ div [ class "name" ] [ text image ]
        , button
            [ class "button"
            , class "-outline"
            , onClick <| RemoveImage image
            ]
            [ text "remove"
            ]
        ]


{-| viewHelp : renders help msg pointing to Vela docs
-}
viewHelp : Html Msg
viewHelp =
    div [] [ text "Need help? Visit our ", a [ href secretsDocsURL ] [ text "docs" ], text "!" ]


{-| viewNameInput : renders name input box
-}
viewNameInput : String -> Bool -> Html Msg
viewNameInput val disable =
    div []
        [ input
            [ disabled disable
            , value val
            , onInput <|
                OnChangeStringField "name"
            , class "secret-name"
            , placeholder "Secret Name"
            ]
            []
        ]


{-| viewValueInput : renders value input box
-}
viewValueInput : String -> String -> Html Msg
viewValueInput val placeholder_ =
    div []
        [ textarea
            [ value val
            , onInput <| OnChangeStringField "value"
            , class "secret-value"
            , placeholder placeholder_
            ]
            []
        ]


{-| viewEventsSelect : renders events input selection
-}
viewEventsSelect : SecretForm -> Html Msg
viewEventsSelect secretUpdate =
    section [ class "events", Util.testAttribute "" ]
        [ h4 [ class "field-header" ]
            [ text "Limit to Events"
            , span [ class "field-description" ]
                [ text "( "
                , em [] [ text "at least one event must be selected" ]
                , text " )"
                ]
            ]
        , div [ class "form-controls", class "-row" ]
            [ checkbox "Push"
                "push"
                (eventEnabled "push" secretUpdate.events)
              <|
                OnChangeEvent "push"
            , checkbox "Pull Request"
                "pull"
                (eventEnabled "pull" secretUpdate.events)
              <|
                OnChangeEvent "pull"
            , checkbox "Deploy"
                "deploy"
                (eventEnabled "deploy" secretUpdate.events)
              <|
                OnChangeEvent "deploy"
            , checkbox "Tag"
                "tag"
                (eventEnabled "tag" secretUpdate.events)
              <|
                OnChangeEvent "tag"
            ]
        ]


{-| viewImagesInput : renders images input box and images
-}
viewImagesInput : SecretForm -> String -> Html Msg
viewImagesInput secret imageInput =
    section [ class "image", Util.testAttribute "" ]
        [ h4 [ class "field-header" ]
            [ text "Limit to Docker Images"
            , span
                [ class "field-description" ]
                [ em [] [ text "(Leave blank to enable this secret for all images)" ]
                ]
            ]
        , div []
            [ input
                [ placeholder "Image Name"
                , onInput <| OnChangeStringField "imageInput"
                , value imageInput
                ]
                []
            , button
                [ class "button"
                , class "-outline"
                , onClick <| AddImage <| String.toLower imageInput
                , disabled <| String.isEmpty <| String.trim imageInput
                ]
                [ text "Add Image"
                ]
            ]
        , div [ class "images" ] <| viewAddedImages secret.images
        ]


{-| radio : takes current value, field id, title for label, and click action and renders an input radio.
-}
radio : String -> String -> Field -> msg -> Html msg
radio value field title msg =
    div [ class "form-control", Util.testAttribute <| "repo-radio-" ++ field ]
        [ input
            [ type_ "radio"
            , id <| "radio-" ++ field
            , checked (value == field)
            , onClick msg
            ]
            []
        , label [ class "form-label", for <| "radio-" ++ field ] [ strong [] [ text title ], text "tip" ]
        ]


{-| allowCommandCheckbox : renders checkbox inputs for selecting allowcommand
-}
allowCommandCheckbox : SecretForm -> Html Msg
allowCommandCheckbox secretUpdate =
    section [ class "type", Util.testAttribute "" ]
        [ h4 [ class "field-header" ]
            [ text "Allow Commands"
            , span [ class "field-description" ]
                [ text "( "
                , em [] [ text "\"No\" will disable this secret in " ]
                , code [] [ text "commands" ]
                , text " )"
                ]
            ]
        , div
            [ class "form-controls", class "-row" ]
            [ radio (Util.boolToYesNo secretUpdate.allowCommand) "yes" "Yes" <| OnChangeAllowCommand "yes"
            , radio (Util.boolToYesNo secretUpdate.allowCommand) "no" "No" <| OnChangeAllowCommand "no"
            ]
        ]



-- HELPERS


{-| eventEnabled : takes event and returns if it is enabled
-}
eventEnabled : String -> List String -> Bool
eventEnabled event =
    List.member event


secretsDocsURL : String
secretsDocsURL =
    "https://go-vela.github.io/docs/concepts/pipeline/secrets/"
