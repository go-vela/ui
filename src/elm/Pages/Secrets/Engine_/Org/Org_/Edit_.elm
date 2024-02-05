{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Secrets.Engine_.Org.Org_.Edit_ exposing (Model, Msg, page, view)

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
import Route.Path
import Shared
import String.Extra
import Utils.Helpers as Util
import Vela exposing (defaultSecretPayload)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { engine : String, org : String, name : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { engine : String, org : String, name : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { navButtons = []
        , utilButtons = []
        , helpCommands = []
        , crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( "Secrets", Just <| Route.Path.SecretsEngine_OrgOrg_ { org = route.params.org, engine = route.params.engine } )
            , ( "Edit", Nothing )
            , ( route.params.name, Nothing )
            ]
        , repo = Nothing
        }



-- INIT


type alias Model =
    { secret : WebData Vela.Secret
    , name : String
    , value : String
    , images : List String
    , image : String
    , allowCommand : Bool
    , allow_events : Vela.AllowEvents
    , confirmingDelete : Bool
    }


init : Shared.Model -> Route { engine : String, org : String, name : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { secret = RemoteData.Loading
      , name = ""
      , value = ""
      , images = []
      , image = ""
      , allowCommand = True
      , allow_events = Vela.defaultAllowEvents
      , confirmingDelete = False
      }
    , Effect.getOrgSecret
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetSecretResponse
        , engine = route.params.engine
        , org = route.params.org
        , name = route.params.name
        }
    )



-- UPDATE


type Msg
    = -- SECRETS
      GetSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | UpdateSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | DeleteSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | NameOnInput String
    | ValueOnInput String
    | ImageOnInput String
    | AddImage String
    | RemoveImage String
    | AllowCommandsOnClick String
    | AllowEventsUpdate { allow_events : Vela.AllowEvents, event : String } Bool
    | SubmitForm
    | ClickDelete
    | CancelDelete
    | ConfirmDelete


update : Shared.Model -> Route { engine : String, org : String, name : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- SECRETS
        GetSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( { model
                        | secret = RemoteData.succeed secret
                        , name = secret.name
                        , allow_events = secret.allow_events
                        , images = secret.images
                        , allowCommand = secret.allowCommand
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

        DeleteSecretResponse response ->
            case response of
                Ok ( _, result ) ->
                    ( model
                    , Effect.batch
                        [ Effect.addAlertSuccess
                            { content = result
                            , addToastIfUnique = True
                            }
                        , Effect.pushPath <|
                            Route.Path.SecretsEngine_OrgOrg_
                                { org = route.params.org
                                , engine = route.params.engine
                                }
                        ]
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
                |> (\m -> { m | allowCommand = Util.yesNoToBool val })
            , Effect.none
            )

        AllowEventsUpdate options val ->
            ( Vela.setAllowEvents model options.event val
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    { defaultSecretPayload
                        | type_ = Just Vela.OrgSecret
                        , org = Just route.params.org
                        , repo = Nothing
                        , team = Nothing
                        , name = Util.stringToMaybe model.name
                        , value = Util.stringToMaybe model.value
                        , images = Just model.images
                        , allowCommand = Just model.allowCommand
                        , allow_events = Just model.allow_events
                    }

                body =
                    Http.jsonBody <| Vela.encodeSecretPayload payload
            in
            ( model
            , Effect.updateOrgSecret
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateSecretResponse
                , engine = route.params.engine
                , org = route.params.org
                , name = route.params.name
                , body = body
                }
            )

        ClickDelete ->
            ( { model | confirmingDelete = True }
            , Effect.none
            )

        CancelDelete ->
            ( { model | confirmingDelete = False }
            , Effect.none
            )

        ConfirmDelete ->
            ( { model | confirmingDelete = False }
            , Effect.deleteOrgSecret
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = DeleteSecretResponse
                , engine = route.params.engine
                , org = route.params.org
                , name = route.params.name
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { engine : String, org : String, name : String } -> Model -> View Msg
view shared route model =
    { title = "Edit Secret"
    , body =
        [ div [ class "manage-secret", Util.testAttribute "manage-secret" ]
            [ div []
                [ h2 [] [ text <| String.Extra.toTitleCase "edit org secret" ]
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
                    , Components.SecretForm.viewAllowEventsSelect
                        shared
                        { msg = AllowEventsUpdate
                        , allow_events = model.allow_events
                        , disabled_ = False
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
                        , value = model.allowCommand
                        , disabled_ = not <| RemoteData.isSuccess model.secret
                        }
                    , Components.SecretForm.viewHelp shared.velaDocsURL
                    , div [ class "buttons" ]
                        [ Components.Form.viewButton
                            { msg = SubmitForm
                            , text_ = "Submit"
                            , classList_ = []
                            , disabled_ = not <| RemoteData.isSuccess model.secret
                            }
                        , if not model.confirmingDelete then
                            Components.Form.viewButton
                                { msg = ClickDelete
                                , text_ = "Delete"
                                , classList_ = []
                                , disabled_ = not <| RemoteData.isSuccess model.secret
                                }

                          else
                            Components.Form.viewButton
                                { msg = CancelDelete
                                , text_ = "Cancel"
                                , classList_ = []
                                , disabled_ = not <| RemoteData.isSuccess model.secret
                                }
                        , if model.confirmingDelete then
                            Components.Form.viewButton
                                { msg = ConfirmDelete
                                , text_ = "Confirm"
                                , classList_ = [ ( "-secret-delete-confirm", True ) ]
                                , disabled_ = not <| RemoteData.isSuccess model.secret
                                }

                          else
                            text ""
                        ]
                    ]
                ]
            ]
        ]
    }
