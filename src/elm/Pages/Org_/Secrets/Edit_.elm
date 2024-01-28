{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Secrets.Edit_ exposing (Model, Msg, page, view)

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
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import String.Extra
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, name : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, name : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { utilButtons = []
        , navButtons = []
        , repo = Nothing
        }



-- INIT


type alias Model =
    { secret : WebData Vela.Secret
    , name : String
    , value : String
    , events : List String
    , images : List String
    , image : String
    , allowCommands : Bool
    }


init : Shared.Model -> Route { org : String, name : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { secret = RemoteData.Loading
      , name = ""
      , value = ""
      , events = [ "push" ]
      , images = []
      , image = ""
      , allowCommands = True
      }
    , Effect.getOrgSecret
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetSecretResponse
        , org = route.params.org
        , name = route.params.name
        }
    )



-- UPDATE


type Msg
    = -- SECRETS
      GetSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | UpdateSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | NameOnInput String
    | ValueOnInput String
    | ImageOnInput String
    | EventOnCheck String Bool
    | AddImage String
    | RemoveImage String
    | AllowCommandsOnClick String
    | SubmitForm


update : Shared.Model -> Route { org : String, name : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( { model
                        | secret = RemoteData.succeed secret
                        , name = secret.name
                        , events = secret.events
                        , images = secret.images
                        , allowCommands = secret.allowCommand
                      }
                    , Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        UpdateSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = "Org secret " ++ secret.name ++ " updated."
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
                        , repo = Nothing
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
            , Effect.updateOrgSecret
                { baseUrl = shared.velaAPI
                , session = shared.session
                , onResponse = UpdateSecretResponse
                , org = route.params.org
                , name = route.params.name
                , body = body
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, name : String } -> Model -> View Msg
view shared route model =
    { title = "Edit Secret"
    , body =
        [ div [ class "manage-secret", Util.testAttribute "manage-secret" ]
            [ div []
                [ h2 [] [ text <| String.Extra.toTitleCase <| "edit " ++ Vela.secretTypeToString Vela.RepoSecret ++ " secret" ]
                , div [ class "secret-form" ]
                    [ Components.Form.viewInput
                        { title = Just "Name"
                        , subtitle = Nothing
                        , id_ = "name"
                        , val = RemoteData.unwrap "" .name model.secret
                        , placeholder_ = "loading..."
                        , classList_ = [ ( "secret-name", True ) ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = NameOnInput
                        , disabled_ = True
                        }
                    , Components.Form.viewTextarea
                        { title = Just "Value"
                        , subtitle = Nothing
                        , id_ = "value"
                        , val = model.value
                        , placeholder_ = RemoteData.unwrap "loading..." (\_ -> "<leave blank to make no change to the value>") model.secret
                        , classList_ = [ ( "secret-value", True ) ]
                        , rows_ = Just 2
                        , wrap_ = Just "soft"
                        , msg = ValueOnInput
                        , disabled_ = not <| RemoteData.isSuccess model.secret
                        }
                    , Components.SecretForm.viewEventsSelect shared
                        { msg = EventOnCheck
                        , events = model.events
                        , disabled_ = not <| RemoteData.isSuccess model.secret
                        }
                    , Components.SecretForm.viewImagesInput
                        { onInput_ = ImageOnInput
                        , addImage = AddImage
                        , removeImage = RemoveImage
                        , images = model.images
                        , imageValue = model.image
                        , disabled_ = not <| RemoteData.isSuccess model.secret
                        }
                    , Components.SecretForm.viewAllowCommandsInput
                        { msg = AllowCommandsOnClick
                        , value = model.allowCommands
                        , disabled_ = not <| RemoteData.isSuccess model.secret
                        }
                    , Components.SecretForm.viewHelp shared.velaDocsURL
                    , Components.SecretForm.viewSubmitButton
                        { msg = SubmitForm
                        , disabled_ = not <| RemoteData.isSuccess model.secret
                        }
                    ]
                ]
            ]
        ]
    }
