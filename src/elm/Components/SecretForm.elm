{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.SecretForm exposing (Form, defaultOrgRepoSecretForm, defaultSharedSecretForm, toForm, viewAllowCommandsInput, viewAllowEventsSelect, viewAllowSubstitutionInput, viewHelp, viewImagesInput)

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
        , value
        )
import Html.Events exposing (onClick)
import Shared
import Url
import Utils.Helpers as Util
import Vela



-- TYPES


{-| Form : an alias for a secrets form.
-}
type alias Form =
    { team : String
    , name : String
    , value : String
    , allowEvents : Vela.AllowEvents
    , images : List String
    , image : String
    , allowCommand : Bool
    , allowSubstitution : Bool
    }


{-| defaultOrgRepoSecretForm : returns a default form for org and repo secrets.
-}
defaultOrgRepoSecretForm : Form
defaultOrgRepoSecretForm =
    { team = ""
    , name = ""
    , value = ""
    , allowEvents = Vela.defaultEnabledAllowEvents
    , images = []
    , image = ""
    , allowCommand = True
    , allowSubstitution = True
    }


{-| defaultSharedSecretForm : returns a default form for shared secrets.
-}
defaultSharedSecretForm : String -> Form
defaultSharedSecretForm team =
    { team =
        if team == "*" then
            ""

        else
            Maybe.withDefault team <| Url.percentDecode team
    , name = ""
    , value = ""
    , allowEvents = Vela.defaultEnabledAllowEvents
    , images = []
    , image = ""
    , allowCommand = False
    , allowSubstitution = False
    }


{-| toForm : converts a secret to a form.
-}
toForm : Vela.Secret -> Form
toForm secret =
    { team = secret.team
    , name = secret.name
    , value = ""
    , allowEvents = secret.allowEvents
    , images = secret.images
    , image = ""
    , allowCommand = secret.allowCommand
    , allowSubstitution = secret.allowSubstitution
    }



-- VIEW


{-| viewImagesInput : renders input for images.
-}
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


{-| viewImage : renders a supplied docker image with option to remove.
-}
viewImage : { msg : String -> msg, image : String } -> Html msg
viewImage { msg, image } =
    div [ class "image", class "chevron" ]
        [ div [ class "name" ] [ text image ]
        , button
            [ class "button"
            , class "-outline"
            , onClick <| msg image
            ]
            [ text "remove"
            ]
        ]


{-| viewAllowCommandsInput : renders radio buttons to control access to secret via commands.
-}
viewAllowCommandsInput : { msg : String -> msg, value : Bool, disabled_ : Bool } -> Html msg
viewAllowCommandsInput { msg, value, disabled_ } =
    section [ Util.testAttribute "allow-commands" ]
        [ div [ class "form-control" ]
            [ strong []
                [ text "Allow Commands"
                , span [ class "field-description" ]
                    [ text "("
                    , em [] [ text "\"No\" will prevent secret injection when " ]
                    , code [] [ text "commands" ]
                    , text " is used)"
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
                , id_ = "secret-allow-command-yes"
                }
            , Components.Form.viewRadio
                { value = Util.boolToYesNo value
                , field = "no"
                , title = "No"
                , subtitle = Nothing
                , msg = msg "no"
                , disabled_ = disabled_
                , id_ = "secret-allow-command-no"
                }
            ]
        ]


{-| viewAllowSubstitutionInput : renders radio buttons to control access to secret via substitution.
-}
viewAllowSubstitutionInput : { msg : String -> msg, value : Bool, disabled_ : Bool } -> Html msg
viewAllowSubstitutionInput { msg, value, disabled_ } =
    section [ Util.testAttribute "allow-substitution" ]
        [ div [ class "form-control" ]
            [ strong []
                [ text "Allow Substitution"
                , span [ class "field-description" ]
                    [ text "("
                    , em [] [ text "\"No\" will prevent substitution" ]
                    , text ")"
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
                , id_ = "secret-allow-substitution-yes"
                }
            , Components.Form.viewRadio
                { value = Util.boolToYesNo value
                , field = "no"
                , title = "No"
                , subtitle = Nothing
                , msg = msg "no"
                , disabled_ = disabled_
                , id_ = "secret-allow-substitution-no"
                }
            ]
        ]


{-| viewHelp : renders link to docs for secrets help.
-}
viewHelp : String -> Html msg
viewHelp docsUrl =
    div [ class "help" ]
        [ text "Need help? Visit our "
        , a
            [ href <| docsUrl ++ "/usage/secrets/"
            ]
            [ text "docs" ]
        , text "!"
        ]


{-| viewAllowEventsSelect : renders Events selection portion of a secret.
-}
viewAllowEventsSelect :
    Shared.Model
    ->
        { msg : { allowEvents : Vela.AllowEvents, event : Vela.AllowEventsField } -> Bool -> msg
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


{-| viewPullRequestWarning : renders disclaimer message for enabling secret for PR events.
-}
viewPullRequestWarning : Html msg
viewPullRequestWarning =
    p [ class "notice" ]
        [ text "Disclaimer: Native secrets do NOT have the "
        , strong [] [ text "pull_request" ]
        , text " event enabled by default. This is intentional to help mitigate exposure via a pull request against the repo. You can override this behavior, at your own risk, for each secret."
        ]
