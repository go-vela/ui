{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Secrets.Edit_ exposing (Model, Msg, page, view)

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
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import String.Extra
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String, name : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String, name : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { utilButtons = []
        , navButtons = []
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


init : Shared.Model -> Route { org : String, repo : String, name : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { secret = RemoteData.Loading
      , name = ""
      , value = ""
      , events = [ "push" ]
      , images = []
      , image = ""
      , allowCommands = True
      }
    , Effect.getRepoSecret
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetSecretResponse
        , org = route.params.org
        , repo = route.params.repo
        , name = route.params.name
        }
    )



-- UPDATE


type Msg
    = GetSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | UpdateSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | NameOnInput String
    | ValueOnInput String
    | ImageOnInput String
    | EventOnCheck String Bool
    | AddImage String
    | RemoveImage String
    | AllowCommandsOnClick String
    | SubmitForm
    | AddAlertCopiedToClipboard String


update : Shared.Model -> Route { org : String, repo : String, name : String } -> Msg -> Model -> ( Model, Effect Msg )
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
                        { content = "Repo secret " ++ secret.name ++ " updated."
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
                        { type_ = Just Vela.RepoSecret
                        , org = Just route.params.org
                        , repo = Just route.params.repo
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
            , Effect.updateRepoSecret
                { baseUrl = shared.velaAPI
                , session = shared.session
                , onResponse = UpdateSecretResponse
                , org = route.params.org
                , repo = route.params.repo
                , name = route.params.name
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


view : Shared.Model -> Route { org : String, repo : String, name : String } -> Model -> View Msg
view shared route model =
    let
        disableForm =
            not <| RemoteData.isSuccess model.secret
    in
    { title = route.params.org ++ "/" ++ route.params.repo ++ "/" ++ route.params.name ++ " Edit Secret"
    , body =
        [ div [ class "manage-secret", Util.testAttribute "manage-secret" ]
            [ div []
                [ h2 [] [ text <| String.Extra.toTitleCase <| "edit " ++ Vela.secretTypeToString Vela.RepoSecret ++ " secret" ]
                , div [ class "secret-form" ]
                    [ -- todo: convert this into a select form that uses list of secrets as input
                      Components.Form.viewInput
                        { label_ = Just "Name"
                        , id_ = "name"
                        , val = RemoteData.unwrap "" .name model.secret
                        , placeholder_ = "loading..."
                        , classList_ = [ ( "secret-name", True ) ]
                        , disabled_ = True
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = NameOnInput
                        }
                    , Components.Form.viewTextarea
                        { label_ = Just "Value"
                        , id_ = "value"
                        , val = model.value
                        , placeholder_ = RemoteData.unwrap "loading..." (\_ -> "<leave blank to make no change to the value>") model.secret
                        , classList_ = [ ( "secret-value", True ) ]
                        , disabled_ = disableForm
                        , rows_ = Just 2
                        , wrap_ = Just "soft"
                        , msg = ValueOnInput
                        }
                    , Components.SecretForm.viewEventsSelect shared
                        { disabled_ = False
                        , msg = EventOnCheck
                        , events = model.events
                        }
                    , Components.SecretForm.viewImagesInput
                        { disabled_ = False
                        , onInput_ = ImageOnInput
                        , addImage = AddImage
                        , removeImage = RemoveImage
                        , images = model.images
                        , imageValue = model.image
                        }
                    , Components.SecretForm.viewAllowCommandsInput
                        { msg = AllowCommandsOnClick
                        , value = model.allowCommands
                        }
                    , Components.SecretForm.viewHelp
                    , Components.SecretForm.viewSubmitButton
                        { msg = SubmitForm
                        }
                    ]
                ]
            ]
        ]
    }
