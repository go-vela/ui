{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Secrets.AddSecret exposing (view)

import Html
    exposing
        ( Html
        , a
        , div
        , em
        , h4
        , section
        , span
        , text
        )
import Html.Attributes
    exposing
        ( class
        , disabled
        , href
        , placeholder
        , value
        )
import Html.Events exposing (onClick, onInput)
import Pages exposing (Page(..))
import Pages.RepoSettings exposing (checkbox)
import Pages.Secrets.Types
    exposing
        ( Args
        , Msg(..)
        , PartialModel
        , SecretUpdate
        )
import RemoteData exposing (RemoteData(..))
import Util
import Vela
    exposing
        ( SecretType(..)
        )


view : PartialModel a msg -> Html Msg
view model =
    div [ class "manage-secrets", Util.testAttribute "manage-secrets" ]
        [ div []
            [ Html.h2 [] [ header model.secretsModel.type_ ]
            , addSecret model.secretsModel
            ]
        ]


header : SecretType -> Html Msg
header type_ =
    case type_ of
        Vela.OrgSecret ->
            text "Add Org Secret"

        Vela.RepoSecret ->
            text "Add Repo Secret"

        Vela.SharedSecret ->
            text "Add Shared Secret"


{-| addSecret : renders secret update form for adding a new secret
-}
addSecret : Args msg -> Html Msg
addSecret secretsModel =
    let
        secretUpdate =
            secretsModel.secretAdd
    in
    div [ class "secret-form" ]
        [ Html.h4 [ class "field-header" ] [ text "Name" ]
        , nameInput secretUpdate.name False
        , Html.h4 [ class "field-header" ] [ text "Value" ]
        , valueInput secretUpdate.value "Secret Value"
        , eventsSelect secretUpdate
        , imagesInput secretUpdate secretUpdate.imageInput
        , help
        , div [ class "-m-t" ]
            [ Html.button [ class "button", class "-outline", onClick Pages.Secrets.Types.AddSecret ] [ text "Add" ]
            ]
        ]


{-| nameInput : renders name input box
-}
nameInput : String -> Bool -> Html Msg
nameInput val disable =
    div []
        [ Html.input
            [ disabled disable
            , value val
            , onInput <|
                OnChangeStringField "name"
            , class "secret-name"
            , Html.Attributes.placeholder "Secret Name"
            ]
            []
        ]


{-| valueInput : renders value input box
-}
valueInput : String -> String -> Html Msg
valueInput val placeholder_ =
    div []
        [ Html.textarea
            [ value val
            , onInput <| OnChangeStringField "value"
            , class "secret-value"
            , Html.Attributes.placeholder placeholder_
            ]
            []
        ]


{-| eventsSelect : renders events input selection
-}
eventsSelect : SecretUpdate -> Html Msg
eventsSelect secretUpdate =
    Html.section [ class "events", Util.testAttribute "" ]
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


{-| imagesInput : renders images input box and images
-}
imagesInput : SecretUpdate -> String -> Html Msg
imagesInput secret imageInput =
    Html.section [ class "image", Util.testAttribute "" ]
        [ Html.h4 [ class "field-header" ]
            [ text "Limit to Docker Images"
            , span
                [ class "field-description" ]
                [ em [] [ text "(Leave blank to enable this secret for all images)" ]
                ]
            ]
        , div []
            [ Html.input
                [ placeholder "Image Name"
                , onInput <| OnChangeStringField "imageInput"
                , value imageInput
                ]
                []
            , Html.button
                [ class "button"
                , class "-outline"
                , class "-slim"
                , class "-m-l"
                , onClick <| AddImage <| String.toLower imageInput
                , disabled <| String.isEmpty <| String.trim imageInput
                ]
                [ text "Add Image"
                ]
            ]
        , div [ class "images" ] <| viewAddedImages secret.images
        ]


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
        [ div [ class "name" ] [ text "enabled for all images" ]

        -- add button to match style
        , Html.button
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
        , Html.button
            [ class "button"
            , class "-outline"
            , onClick <| RemoveImage image
            ]
            [ text "remove"
            ]
        ]


{-| help : renders help msg pointing to Vela docs
-}
help : Html Msg
help =
    div [] [ text "Need help? Visit our ", a [ href secretsDocsURL ] [ text "docs" ], text "!" ]


secretsDocsURL : String
secretsDocsURL =
    "https://go-vela.github.io/docs/concepts/pipeline/secrets/"



-- HELPERS


{-| eventEnabled : takes event and returns if it is enabled
-}
eventEnabled : String -> List String -> Bool
eventEnabled event =
    List.member event
