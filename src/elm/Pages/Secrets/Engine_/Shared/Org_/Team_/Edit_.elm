{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Secrets.Engine_.Shared.Org_.Team_.Edit_ exposing (Model, Msg, page, view)

import Auth
import Components.Crumbs
import Components.Form
import Components.Nav
import Components.SecretForm
import Effect exposing (Effect)
import Html exposing (div, h2, main_, text)
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
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela exposing (defaultSecretPayload)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { engine : String, org : String, team : String, name : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { engine : String, org : String, team : String, name : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "View Shared Secret"
              , content =
                    "vela view secret --secret.engine native --secret.type shared --org "
                        ++ route.params.org
                        ++ "--team octokitties --name foo"
              , docs = Just "secret/view"
              }
            , { name = "Update Secrets Help"
              , content = "vela update secret -h"
              , docs = Just "secret/update"
              }
            , { name = "Update Shared Secret Example"
              , content =
                    "vela update secret --secret.engine native --secret.type shared --org "
                        ++ route.params.org
                        ++ " --team octokitties --name foo --value bar"
              , docs = Just "secret/update"
              }
            ]
        }



-- INIT


type alias Model =
    { secret : WebData Vela.Secret
    , form : Components.SecretForm.Form
    , confirmingDelete : Bool
    }


init : Shared.Model -> Route { engine : String, org : String, team : String, name : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { secret = RemoteData.Loading
      , form = Components.SecretForm.defaultSharedSecretForm route.params.team
      , confirmingDelete = False
      }
    , Effect.getSharedSecret
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetSecretResponse
        , engine = route.params.engine
        , org = route.params.org
        , team = route.params.team
        , name = route.params.name
        }
    )



-- UPDATE


type Msg
    = NoOp
      -- SECRETS
    | GetSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | UpdateSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | DeleteSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | ValueOnInput String
    | ImageOnInput String
    | AddImage String
    | RemoveImage String
    | AllowCommandsOnClick String
    | AllowSubstitutionOnClick String
    | AllowEventsUpdate { allowEvents : Vela.AllowEvents, event : Vela.AllowEventsField } Bool
    | SubmitForm
    | ClickDelete
    | CancelDelete
    | ConfirmDelete


update : Shared.Model -> Route { engine : String, org : String, team : String, name : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    let
        form =
            model.form
    in
    case msg of
        NoOp ->
            ( model, Effect.none )

        -- SECRETS
        GetSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( { model
                        | secret = RemoteData.succeed secret
                        , form = Components.SecretForm.toForm secret
                      }
                    , Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        UpdateSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = "Updated shared secret '" ++ route.params.name ++ "'."
                        , addToastIfUnique = True
                        , link = Nothing
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        DeleteSecretResponse response ->
            case response of
                Ok ( _, result ) ->
                    ( model
                    , Effect.batch
                        [ Effect.addAlertSuccess
                            { content = "Deleted shared secret '" ++ route.params.name ++ "'."
                            , addToastIfUnique = True
                            , link = Nothing
                            }
                        , Effect.pushPath <|
                            Route.Path.SecretsEngine_SharedOrg_Team_
                                { org = route.params.org
                                , team = route.params.team
                                , engine = route.params.engine
                                }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        ValueOnInput val ->
            ( { model | form = { form | value = val } }
            , Effect.none
            )

        ImageOnInput val ->
            ( { model | form = { form | image = val } }
            , Effect.none
            )

        AddImage image ->
            ( { model
                | form =
                    { form
                        | images =
                            form.images
                                |> List.append [ image ]
                                |> List.Extra.unique
                        , image = ""
                    }
              }
            , Effect.none
            )

        RemoveImage image ->
            ( { model
                | form =
                    { form
                        | images =
                            form.images
                                |> List.filter ((/=) image)
                    }
              }
            , Effect.none
            )

        AllowCommandsOnClick val ->
            ( { model
                | form =
                    { form
                        | allowCommand = Util.yesNoToBool val
                    }
              }
            , Effect.none
            )

        AllowSubstitutionOnClick val ->
            ( { model
                | form =
                    { form
                        | allowSubstitution = Util.yesNoToBool val
                    }
              }
            , Effect.none
            )

        AllowEventsUpdate options val ->
            ( { model
                | form =
                    Vela.setAllowEvents model.form options.event val
              }
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    { defaultSecretPayload
                        | type_ = Just Vela.RepoSecret
                        , org = Just route.params.org
                        , repo = Nothing
                        , team = Just route.params.team
                        , name = Util.stringToMaybe form.name
                        , value = Util.stringToMaybe form.value
                        , allowEvents = Just form.allowEvents
                        , images = Just form.images
                        , allowCommand = Just form.allowCommand
                        , allowSubstitution = Just form.allowSubstitution
                    }

                body =
                    Http.jsonBody <| Vela.encodeSecretPayload payload
            in
            ( model
            , Effect.updateSharedSecret
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateSecretResponse
                , engine = route.params.engine
                , org = route.params.org
                , team = route.params.team
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
            , Effect.deleteSharedSecret
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = DeleteSecretResponse
                , engine = route.params.engine
                , org = route.params.org
                , team = route.params.team
                , name = route.params.name
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { engine : String, org : String, team : String, name : String } -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.team, Nothing )
            , ( "Shared Secrets", Just <| Route.Path.SecretsEngine_SharedOrg_Team_ { engine = route.params.engine, org = route.params.org, team = route.params.team } )
            , ( "Edit", Nothing )
            , ( route.params.name, Nothing )
            ]
    in
    { title = "Edit Secret"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ class "manage-secret", Util.testAttribute "manage-secret" ]
                [ div []
                    [ h2 [] [ text <| String.Extra.toTitleCase "edit shared secret" ]
                    , div [ class "secret-form" ]
                        [ Components.Form.viewInput
                            { title = Just "Name"
                            , subtitle = Nothing
                            , id_ = "name"
                            , val = RemoteData.unwrap "" .name model.secret
                            , placeholder_ = "Loading..."
                            , classList_ = [ ( "secret-name", True ) ]
                            , rows_ = Nothing
                            , wrap_ = Nothing
                            , msg = \_ -> NoOp
                            , disabled_ = True
                            }
                        , Components.Form.viewTextarea
                            { title = Just "Value"
                            , subtitle = Nothing
                            , id_ = "value"
                            , val = model.form.value
                            , placeholder_ = RemoteData.unwrap "Loading..." (\_ -> "<leave blank to make no change to the value>") model.secret
                            , classList_ = [ ( "secret-value", True ) ]
                            , rows_ = Just 2
                            , wrap_ = Just "soft"
                            , msg = ValueOnInput
                            , disabled_ = not <| RemoteData.isSuccess model.secret
                            }
                        , Components.SecretForm.viewAllowEventsSelect
                            shared
                            { msg = AllowEventsUpdate
                            , allowEvents = model.form.allowEvents
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewImagesInput
                            { onInput_ = ImageOnInput
                            , addImage = AddImage
                            , removeImage = RemoveImage
                            , images = model.form.images
                            , imageValue = model.form.image
                            , disabled_ = not <| RemoteData.isSuccess model.secret
                            }
                        , Components.SecretForm.viewAllowCommandsInput
                            { msg = AllowCommandsOnClick
                            , value = model.form.allowCommand
                            , disabled_ = not <| RemoteData.isSuccess model.secret
                            }
                        , Components.SecretForm.viewAllowSubstitutionInput
                            { msg = AllowSubstitutionOnClick
                            , value = model.form.allowSubstitution
                            , disabled_ = not <| RemoteData.isSuccess model.secret
                            }
                        , Components.SecretForm.viewHelp shared.velaDocsURL
                        , div [ class "buttons" ]
                            [ Components.Form.viewButton
                                { id_ = "submit"
                                , msg = SubmitForm
                                , text_ = "Update Secret"
                                , classList_ = []
                                , disabled_ = not <| RemoteData.isSuccess model.secret
                                }
                            , if not model.confirmingDelete then
                                Components.Form.viewButton
                                    { id_ = "delete"
                                    , msg = ClickDelete
                                    , text_ = "Delete Secret"
                                    , classList_ =
                                        [ ( "-outline", True )
                                        ]
                                    , disabled_ = not <| RemoteData.isSuccess model.secret
                                    }

                              else
                                Components.Form.viewButton
                                    { id_ = "delete-cancel"
                                    , msg = CancelDelete
                                    , text_ = "Cancel"
                                    , classList_ =
                                        [ ( "-outline", True )
                                        ]
                                    , disabled_ = not <| RemoteData.isSuccess model.secret
                                    }
                            , if model.confirmingDelete then
                                Components.Form.viewButton
                                    { id_ = "delete-confirm"
                                    , msg = ConfirmDelete
                                    , text_ = "Confirm Delete"
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
        ]
    }
