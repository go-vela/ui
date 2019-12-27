{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.AddRepos exposing (view)

import Dict
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , details
        , div
        , h1
        , p
        , span
        , summary
        , text
        )
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Routes exposing (Route(..))
import Search
    exposing
        ( RepoSearchFilters
        , Search
        , filterRepo
        , repoSearchBarGlobal
        , repoSearchBarLocal
        , searchFilterGlobal
        , searchFilterLocal
        , shouldSearch
        )
import Svg.Attributes
import SvgBuilder
import Util
import Vela
    exposing
        ( AddRepo
        , AddRepos
        , FavoriteRepo
        , FavoritesModel
        , Org
        , Repositories
        , Repository
        , SourceRepositories
        , repoFavorited
        )


{-| view : takes model and renders account page for adding repos to overview
-}
view : WebData SourceRepositories -> FavoritesModel -> RepoSearchFilters -> Search msg -> AddRepo msg -> AddRepos msg -> FavoriteRepo msg -> Html msg
view sourceRepos favorites sourceSearchFilters search addRepo addRepos favoriteRepo =
    let
        loading =
            div []
                [ h1 []
                    [ text "Loading your Repositories"
                    , span [ class "loading-ellipsis" ] []
                    ]
                , p []
                    [ text <|
                        "Hang tight while we grab the list of repositories that you have access to from Github. If you have access to "
                            ++ "a lot of organizations and repositories this might take a little while."
                    ]
                ]
    in
    case sourceRepos of
        RemoteData.Success repos ->
            div [ class "source-repos", Util.testAttribute "source-repos" ]
                [ repoSearchBarGlobal sourceSearchFilters search
                , viewSourceRepos repos favorites sourceSearchFilters search addRepo addRepos favoriteRepo
                ]

        RemoteData.Loading ->
            loading

        RemoteData.NotAsked ->
            loading

        RemoteData.Failure _ ->
            div []
                [ p []
                    [ text <|
                        "There was an error fetching your available repositories... Click Refresh or try again later!"
                    ]
                ]


{-| viewSourceRepos : takes model and source repos and renders them based on user search
-}
viewSourceRepos : SourceRepositories -> FavoritesModel -> RepoSearchFilters -> Search msg -> AddRepo msg -> AddRepos msg -> FavoriteRepo msg -> Html msg
viewSourceRepos sourceRepos favorites sourceSearchFilters search addRepo addRepos favoriteRepo =
    if shouldSearch <| searchFilterGlobal sourceSearchFilters then
        -- Search and render repos using the global filter
        searchReposGlobal favorites sourceSearchFilters sourceRepos addRepo favoriteRepo

    else
        -- Render repos normally
        sourceRepos
            |> Dict.toList
            |> Util.filterEmptyLists
            |> List.map (\( org, repos_ ) -> viewSourceOrg favorites sourceSearchFilters org repos_ search addRepo addRepos favoriteRepo)
            |> div [ class "repo-list" ]


{-| viewSourceOrg : renders the source repositories available to a user by org
-}
viewSourceOrg : FavoritesModel -> RepoSearchFilters -> Org -> Repositories -> Search msg -> AddRepo msg -> AddRepos msg -> FavoriteRepo msg -> Html msg
viewSourceOrg favorites sourceSearchFilters org repos search addRepo addRepos favoriteRepo =
    let
        ( repos_, filtered, content ) =
            if shouldSearch <| searchFilterLocal org sourceSearchFilters then
                -- Search and render repos using the global filter
                searchReposLocal favorites org sourceSearchFilters repos addRepo favoriteRepo

            else
                -- Render repos normally
                ( repos, False, List.map (viewSourceRepo favorites addRepo favoriteRepo) repos )
    in
    viewSourceOrgDetails sourceSearchFilters org repos_ filtered content search addRepos


{-| viewSourceOrgDetails : renders the source repositories by org as an html details element
-}
viewSourceOrgDetails : RepoSearchFilters -> Org -> Repositories -> Bool -> List (Html msg) -> Search msg -> AddRepos msg -> Html msg
viewSourceOrgDetails sourceSearchFilters org repos filtered content search addRepos =
    div [ class "org" ]
        [ details [ class "details", class "repo-item" ] <|
            viewSourceOrgSummary sourceSearchFilters org repos filtered content search addRepos
        ]


{-| viewSourceOrgSummary : renders the source repositories details summary
-}
viewSourceOrgSummary : RepoSearchFilters -> Org -> Repositories -> Bool -> List (Html msg) -> Search msg -> AddRepos msg -> List (Html msg)
viewSourceOrgSummary sourceSearchFilters org repos filtered content search addRepos =
    summary [ class "summary", Util.testAttribute <| "source-org-" ++ org ]
        [ div [ class "org-header" ]
            [ text org
            , viewRepoCount repos
            ]
        ]
        :: div [ class "source-actions" ]
            [ repoSearchBarLocal sourceSearchFilters org search
            , addReposBtn org repos filtered addRepos
            ]
        :: content


{-| viewSourceRepo : renders single repo within a list of org repos

    viewSourceRepo uses model.SourceRepositories and buildAddRepoElement to determine the state of each specific 'Add' button

-}
viewSourceRepo : FavoritesModel -> AddRepo msg -> FavoriteRepo msg -> Repository -> Html msg
viewSourceRepo favoritesModel addRepo favoriteRepo repo =
    div [ class "-item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div [] [ text repo.name ]
        , div []
            [ SvgBuilder.favoritesStar [ Svg.Attributes.class "-cursor", onClick <| favoriteRepo repo.org repo.name ] <| repoFavorited repo.org repo.name favoritesModel
            , buildAddRepoElement repo addRepo
            ]
        ]


{-| viewSearchedSourceRepo : renders single repo when searching across all repos
-}
viewSearchedSourceRepo : FavoritesModel -> AddRepo msg -> FavoriteRepo msg -> Repository -> Html msg
viewSearchedSourceRepo favoritesModel addRepo favoriteRepo repo =
    div [ class "-item", Util.testAttribute <| "source-repo-" ++ repo.name ]
        [ div []
            [ text <| repo.org ++ "/" ++ repo.name ]
        , div
            []
            [ SvgBuilder.favoritesStar [ Svg.Attributes.class "-cursor", onClick <| favoriteRepo repo.org repo.name ] <| repoFavorited repo.org repo.name favoritesModel
            , buildAddRepoElement repo addRepo
            ]
        ]


{-| viewRepoCount : renders the amount of repos available within an org
-}
viewRepoCount : List a -> Html msg
viewRepoCount repos =
    span [ class "repo-count", Util.testAttribute "source-repo-count" ] [ code [] [ text <| (String.fromInt <| List.length repos) ++ " repos" ] ]


{-| addReposBtn : takes List of repos and renders a button to add them all at once, texts depends on user input filter
-}
addReposBtn : Org -> Repositories -> Bool -> AddRepos msg -> Html msg
addReposBtn org repos filtered addRepos =
    button [ class "-inverted", Util.testAttribute <| "add-org-" ++ org, onClick (addRepos repos) ]
        [ text <|
            if filtered then
                "Add Results"

            else
                "Add All"
        ]


{-| buildAddRepoElement : builds action element for adding single repos
-}
buildAddRepoElement : Repository -> AddRepo msg -> Html msg
buildAddRepoElement repo addRepo =
    case repo.added of
        RemoteData.NotAsked ->
            button [ class "-solid", onClick (addRepo repo) ] [ text "Add" ]

        RemoteData.Loading ->
            div [ class "repo-add--adding" ] [ span [ class "repo-add--adding-text" ] [ text "Adding" ], span [ class "loading-ellipsis" ] [] ]

        RemoteData.Failure _ ->
            div [ class "repo-add--failed", onClick (addRepo repo) ] [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]

        RemoteData.Success addedStatus ->
            if addedStatus then
                div [ class "-added-container" ]
                    [ div [ class "repo-add--added" ] [ FeatherIcons.check |> FeatherIcons.toHtml [ attribute "role" "img" ], span [] [ text "Added" ] ]
                    , a [ class "-btn", class "-solid", class "-view", Routes.href <| Routes.RepositoryBuilds repo.org repo.name Nothing Nothing ] [ text "View" ]
                    ]

            else
                div [ class "repo-add--failed", onClick (addRepo repo) ] [ FeatherIcons.refreshCw |> FeatherIcons.toHtml [ attribute "role" "img" ], text "Failed" ]


{-| searchReposGlobal : takes source repositories and search filters and renders filtered repos
-}
searchReposGlobal : FavoritesModel -> RepoSearchFilters -> SourceRepositories -> AddRepo msg -> FavoriteRepo msg -> Html msg
searchReposGlobal favoritesModel filters repos addRepo favoriteRepo =
    let
        filteredRepos =
            repos
                |> Dict.toList
                |> Util.filterEmptyLists
                |> List.map (\( _, repos_ ) -> repos_)
                |> List.concat
                |> List.filter (\repo -> filterRepo filters Nothing <| repo.org ++ "/" ++ repo.name)
    in
    div [ class "filtered-repos" ] <|
        -- Render the found repositories
        if not <| List.isEmpty filteredRepos then
            filteredRepos |> List.map (\repo -> viewSearchedSourceRepo favoritesModel addRepo favoriteRepo repo)

        else
            -- No repos matched the search
            [ div [ class "-no-repos" ] [ text "No results" ] ]


{-| searchReposLocal : takes repo search filters, the org, and repos and renders a list of repos based on user-entered text
-}
searchReposLocal : FavoritesModel -> Org -> RepoSearchFilters -> Repositories -> AddRepo msg -> FavoriteRepo msg -> ( Repositories, Bool, List (Html msg) )
searchReposLocal favoritesModel org filters repos addRepo favoriteRepo =
    -- Filter the repos if the user typed more than 2 characters
    let
        filteredRepos =
            List.filter (\repo -> filterRepo filters (Just org) repo.name) repos
    in
    ( filteredRepos
    , True
    , if not <| List.isEmpty filteredRepos then
        List.map (viewSourceRepo favoritesModel addRepo favoriteRepo) filteredRepos

      else
        [ div [ class "-no-repos" ] [ text "No results" ] ]
    )
