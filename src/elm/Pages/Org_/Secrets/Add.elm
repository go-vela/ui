{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Secrets.Add exposing (Model, Msg, page, view)

import Auth
import Components.Form
import Components.SecretForm
import Effect exposing (Effect)
import Html exposing (div, h2, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import Route exposing (Route)
import Shared
import String.Extra
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { utilButtons = []
        , navButtons = []
        }



-- INIT


type alias Model =
    { name : String
    , value : String
    , events : List String
    , images : List String
    , image : String
    , allowCommands : Bool
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { name = ""
      , value = ""
      , events = [ "push" ]
      , images = []
      , image = ""
      , allowCommands = True
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | NameOnInput String
    | ValueOnInput String
    | ImageOnInput String
    | EventOnCheck String Bool
    | AddImage String
    | RemoveImage String
    | AllowCommandsOnClick String
    | SubmitForm
    | AddAlertCopiedToClipboard String


update : Shared.Model -> Route { org : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        AddSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = secret.name ++ " added to org secrets."
                        , addToastIfUnique = True
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        NameOnInput val ->
            ( { model | name = val }
            , Effect.none
            )

        ValueOnInput val ->
            ( { model | value = val }
            , Effect.none
            )

        ImageOnInput val ->
            ( { model | image = val }
            , Effect.none
            )

        EventOnCheck event val ->
            let
                updatedEvents =
                    if val then
                        model.events
                            |> List.append [ event ]
                            |> List.Extra.unique

                    else
                        model.events
                            |> List.filter ((/=) event)
            in
            ( { model | events = updatedEvents }
            , Effect.none
            )

        AddImage image ->
            ( { model
                | images =
                    model.images
                        |> List.append [ image ]
                        |> List.Extra.unique
                , image = ""
              }
            , Effect.none
            )

        RemoveImage image ->
            ( { model
                | images =
                    model.images
                        |> List.filter ((/=) image)
              }
            , Effect.none
            )

        AllowCommandsOnClick val ->
            ( model
                |> (\m -> { m | allowCommands = Util.yesNoToBool val })
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    Vela.buildSecretPayload
                        { type_ = Just Vela.OrgSecret
                        , org = Just route.params.org
                        , repo = Just "*"
                        , team = Nothing
                        , name = Util.stringToMaybe model.name
                        , value = Util.stringToMaybe model.value
                        , events = Just model.events
                        , images = Just model.images
                        , allowCommands = Just model.allowCommands
                        }

                body =
                    Http.jsonBody <| Vela.encodeSecretPayload payload
            in
            ( model
            , Effect.addOrgSecret
                { baseUrl = shared.velaAPI
                , session = shared.session
                , onResponse = AddSecretResponse
                , org = route.params.org
                , body = body
                }
            )

        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess { content = contentCopied, addToastIfUnique = False }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String } -> Model -> View Msg
view shared route model =
    { title = "Add Secret"
    , body =
        [ div [ class "manage-secret", Util.testAttribute "manage-secret" ]
            [ div []
                [ h2 [] [ text <| String.Extra.toTitleCase <| "add " ++ Vela.secretTypeToString Vela.RepoSecret ++ " secret" ]
                , div [ class "secret-form" ]
                    [ Components.Form.viewInput
                        { title = Just "Name"
                        , subtitle = Nothing
                        , id_ = "name"
                        , val = model.name
                        , placeholder_ = "Secret Name"
                        , classList_ = [ ( "secret-name", True ) ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = NameOnInput
                        , disabled_ = False
                        }
                    , Components.Form.viewTextarea
                        { title = Just "Value"
                        , subtitle = Nothing
                        , id_ = "value"
                        , val = model.value
                        , placeholder_ = "secret-value"
                        , classList_ = [ ( "secret-value", True ) ]
                        , rows_ = Just 2
                        , wrap_ = Just "soft"
                        , msg = ValueOnInput
                        , disabled_ = False
                        }
                    , Components.SecretForm.viewEventsSelect shared
                        { msg = EventOnCheck
                        , events = model.events
                        , disabled_ = False
                        }
                    , Components.SecretForm.viewImagesInput
                        { onInput_ = ImageOnInput
                        , addImage = AddImage
                        , removeImage = RemoveImage
                        , images = model.images
                        , imageValue = model.image
                        , disabled_ = False
                        }
                    , Components.SecretForm.viewAllowCommandsInput
                        { msg = AllowCommandsOnClick
                        , value = model.allowCommands
                        , disabled_ = False
                        }
                    , Components.SecretForm.viewHelp
                    , Components.SecretForm.viewSubmitButton
                        { msg = SubmitForm
                        , disabled_ = False
                        }
                    ]
                ]
            ]
        ]
    }