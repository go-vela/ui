{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Dash.Secrets.Engine_.Org.Org_.Name_ exposing (Model, Msg, page, view)

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


{-| page : takes user, shared model, route, and returns a specific org secret's page.
-}
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


{-| toLayout : takes user, route, model, and passes an org's secret's info to Layouts.
-}
toLayout : Auth.User -> Route { engine : String, org : String, name : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "View Org Secret"
              , content =
                    "vela view secret --secret.engine native --secret.type org --org "
                        ++ route.params.org
                        ++ " --name "
                        ++ route.params.name
              , docs = Just "secret/view"
              }
            , { name = "Update Secrets Help"
              , content = "vela update secrets -h"
              , docs = Just "secret/update"
              }
            , { name = "Update Org Secret Example"
              , content =
                    "vela update secret --secret.engine native --secret.type org --org "
                        ++ route.params.org
                        ++ " --name "
                        ++ route.params.name
                        ++ " --value vela"
              , docs = Just "secret/update"
              }
            , { name = "Delete Org Secret"
              , content =
                    "vela remove secret --secret.engine native --secret.type org --org "
                        ++ route.params.org
                        ++ " --name "
                        ++ route.params.name
              , docs = Just "secret/remove"
              }
            ]
        }



-- INIT


{-| Model : alias for a model object for an org's secret's info.
-}
type alias Model =
    { secret : WebData Vela.Secret
    , form : Components.SecretForm.Form
    , confirmingDelete : Bool
    }


{-| init : takes in a shared model, route, and returns a model and effect.
-}
init : Shared.Model -> Route { engine : String, org : String, name : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { secret = RemoteData.Loading
      , form = Components.SecretForm.defaultOrgRepoSecretForm
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


{-| Msg : custom type with possible messages.
-}
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
    | OrgOnInput String
    | RepoOnInput String
    | AddRepo String
    | RemoveRepo String
    | AllowCommandsOnClick String
    | AllowSubstitutionOnClick String
    | AllowEventsUpdate { allowEvents : Vela.AllowEvents, event : Vela.AllowEventsField } Bool
    | SubmitForm
    | ClickDelete
    | CancelDelete
    | ConfirmDelete


{-| update : takes current models, route, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { engine : String, org : String, name : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    let
        form =
            model.form
    in
    case msg of
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
                    ( { model
                        | secret = RemoteData.succeed secret
                        , form = Components.SecretForm.toForm secret
                      }
                    , Effect.addAlertSuccess
                        { content = "Updated org secret '" ++ secret.name ++ "'."
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
                            { content = "Deleted org secret '" ++ route.params.name ++ "'."
                            , addToastIfUnique = True
                            , link = Nothing
                            }
                        , Effect.pushPath <|
                            Route.Path.Dash_Secrets_Engine__Org_Org_
                                { org = route.params.org
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

        NameOnInput val ->
            ( { model | form = { form | name = val } }
            , Effect.none
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

        OrgOnInput val ->
            ( { model | form = { form | org = val } }
            , Effect.none
            )

        RepoOnInput val ->
            ( { model | form = { form | repo = val } }
            , Effect.none
            )

        AddRepo repo ->
            ( { model
                | form =
                    { form
                        | repoAllowlist =
                            form.repoAllowlist
                                |> List.append [ repo ]
                                |> List.Extra.unique
                        , org = ""
                        , repo = ""
                    }
              }
            , Effect.none
            )

        RemoveRepo repo ->
            ( { model
                | form =
                    { form
                        | repoAllowlist =
                            form.repoAllowlist
                                |> List.filter ((/=) repo)
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
                        | type_ = Just Vela.OrgSecret
                        , org = Just route.params.org
                        , repo = Nothing
                        , team = Nothing
                        , name = Util.stringToMaybe form.name
                        , value = Util.stringToMaybe form.value
                        , allowEvents = Just form.allowEvents
                        , images = Just form.images
                        , allowCommand = Just form.allowCommand
                        , allowSubstitution = Just form.allowSubstitution
                        , repoAllowlist = Just form.repoAllowlist
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


{-| subscriptions : takes model and returns that there are no subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes models, route, and creates the html for a specific org secret's page.
-}
view : Shared.Model -> Route { engine : String, org : String, name : String } -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( "Org Secrets", Just <| Route.Path.Dash_Secrets_Engine__Org_Org_ { org = route.params.org, engine = route.params.engine } )
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
                    [ h2 [] [ text <| String.Extra.toTitleCase "edit org secret" ]
                    , div [ class "secret-form" ]
                        [ Components.Form.viewInputSection
                            { title = Just "Name"
                            , subtitle = Nothing
                            , id_ = "name"
                            , val = RemoteData.unwrap "" .name model.secret
                            , placeholder_ = "Loading..."
                            , classList_ = [ ( "secret-name", True ) ]
                            , rows_ = Nothing
                            , wrap_ = Nothing
                            , msg = NameOnInput
                            , disabled_ = True
                            , min = Nothing
                            , max = Nothing
                            , required = False
                            }
                        , Components.Form.viewTextareaSection
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
                            , focusOutFunc = Nothing
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
                        , Components.SecretForm.viewRepoAllowlistInput
                            { onOrgInput_ = OrgOnInput
                            , onRepoInput_ = RepoOnInput
                            , addRepo = AddRepo
                            , removeRepo = RemoveRepo
                            , repos = model.form.repoAllowlist
                            , orgValue = model.form.org
                            , repoValue = model.form.repo
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
                                    { msg = CancelDelete
                                    , text_ = "Cancel"
                                    , classList_ =
                                        [ ( "-outline", True )
                                        ]
                                    , disabled_ = not <| RemoteData.isSuccess model.secret
                                    , id_ = "delete-cancel"
                                    }
                            , if model.confirmingDelete then
                                Components.Form.viewButton
                                    { msg = ConfirmDelete
                                    , text_ = "Confirm Delete"
                                    , classList_ =
                                        [ ( "-secret-delete-confirm", True )
                                        ]
                                    , disabled_ = not <| RemoteData.isSuccess model.secret
                                    , id_ = "delete-confirm"
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
