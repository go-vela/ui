{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.SecretForm exposing (..)

import Components.Form
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , div
        , em
        , label
        , p
        , section
        , span
        , strong
        , text
        )
import Html.Attributes
    exposing
        ( class
        , disabled
        , for
        , href
        , id
        , target
        , value
        )
import Html.Events exposing (onClick)
import Shared
import Utils.Helpers as Util
import Vela



-- VIEW


viewAllowEventsSelect :
    Shared.Model
    ->
        { msg : { allowEvents : Vela.AllowEvents, event : String } -> Bool -> msg
        , allowEvents : Vela.AllowEvents
        , disabled_ : Bool
        }
    -> Html msg
viewAllowEventsSelect shared props =
    section []
        [ div [ for "events-select" ]
            ([ strong [] [ text "Limit to Events" ]
             , span [ class "field-description" ]
                [ text "( "
                , em [] [ text "at least one event must be selected" ]
                , text " )"
                ]
             , viewPullRequestWarning
             ]
                ++ Components.Form.viewAllowEvents
                    shared
                    props
            )
        ]


viewPullRequestWarning : Html msg
viewPullRequestWarning =
    p [ class "notice" ]
        [ text "Disclaimer: Native secrets do NOT have the "
        , strong [] [ text "pull_request" ]
        , text " event enabled by default. This is intentional to help mitigate exposure via a pull request against the repo. You can override this behavior, at your own risk, for each secret."
        ]


viewImagesInput :
    { onInput_ : String -> msg
    , addImage : String -> msg
    , removeImage : String -> msg
    , images : List String
    , imageValue : String
    , disabled_ : Bool
    }
    -> Html msg
viewImagesInput { onInput_, addImage, removeImage, images, imageValue, disabled_ } =
    section []
        [ div
            [ id "image-select"
            , class "form-control"
            , class "-stack"
            , class "images-container"
            ]
            [ label
                [ for "image-select"
                , class "form-label"
                ]
                [ strong [] [ text "Limit to Docker Images" ]
                , span
                    [ class "field-description" ]
                    [ em [] [ text "(Leave blank to enable this secret for all images)" ]
                    ]
                ]
            , div [ class "parameters-inputs" ]
                [ Components.Form.viewInput
                    { title = Nothing
                    , subtitle = Nothing
                    , id_ = "image-name"
                    , val = imageValue
                    , placeholder_ = "Image Name"
                    , classList_ = [ ( "image-input", True ) ]
                    , rows_ = Just 2
                    , wrap_ = Just "soft"
                    , msg = onInput_
                    , disabled_ = disabled_
                    }
                , button
                    [ class "button"
                    , class "-outline"
                    , class "add-image"
                    , Util.testAttribute "add-image-button"
                    , onClick <| addImage <| String.toLower imageValue
                    , disabled <| String.isEmpty <| String.trim imageValue
                    ]
                    [ text "Add Image"
                    ]
                ]
            ]
        , div [ class "images", Util.testAttribute "images-list" ] <|
            if List.length images > 0 then
                List.map (\image -> viewImage { msg = removeImage, image = image }) <| List.reverse images

            else
                [ div [ class "no-images" ]
                    [ div
                        [ class "none"
                        ]
                        [ code [] [ text "enabled for all images" ]
                        ]
                    ]
                ]
        ]


viewImage : { msg : String -> msg, image : String } -> Html msg
viewImage { msg, image } =
    div [ class "image", class "chevron" ]
        [ button
            [ class "button"
            , class "-outline"
            , onClick <| msg image
            ]
            [ text "remove"
            ]
        , div [ class "name" ] [ text image ]
        ]


viewAllowCommandsInput : { msg : String -> msg, value : Bool, disabled_ : Bool } -> Html msg
viewAllowCommandsInput { msg, value, disabled_ } =
    section [ Util.testAttribute "allow-commands" ]
        [ div [ class "form-control" ]
            [ strong []
                [ text "Allow Commands"
                , span [ class "field-description" ]
                    [ text "( "
                    , em [] [ text "\"No\" will disable this secret in " ]
                    , code [] [ text "commands" ]
                    , text " )"
                    ]
                ]
            ]
        , div
            [ class "form-controls", class "-stack" ]
            [ Components.Form.viewRadio
                { value = Util.boolToYesNo value
                , field = "yes"
                , title = "Yes"
                , subtitle = Nothing
                , msg = msg "yes"
                , disabled_ = disabled_
                }
            , Components.Form.viewRadio
                { value = Util.boolToYesNo value
                , field = "no"
                , title = "No"
                , subtitle = Nothing
                , msg = msg "no"
                , disabled_ = disabled_
                }
            ]
        ]


viewHelp : String -> Html msg
viewHelp docsUrl =
    div [ class "help" ]
        [ text "Need help? Visit our "
        , a
            [ href <| docsUrl ++ "/usage/secrets/"
            , target "_blank"
            ]
            [ text "docs" ]
        , text "!"
        ]
