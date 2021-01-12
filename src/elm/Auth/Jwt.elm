{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Auth.Jwt exposing
    ( JwtAccessToken
    , JwtAccessTokenClaims
    , decodeJwtAccessToken
    , decodeJwtAccessTokenClaims
    , defaultJwtAccessTokenClaims
    , extractJwtClaims
    )

import Json.Decode as Decode exposing (Decoder, bool, field, int, string)
import Json.Decode.Pipeline exposing (required)
import Time
import Util


type alias JwtAccessToken =
    String


decodeJwtAccessToken : Decoder JwtAccessToken
decodeJwtAccessToken =
    field "token" string


{-| JwtAccessTokenClaims defines the shape
of the access token claims
-}
type alias JwtAccessTokenClaims =
    { is_admin : Bool
    , is_active : Bool
    , exp : Time.Posix
    , iat : Time.Posix
    , sub : String
    }


decodeJwtAccessTokenClaims : Decoder JwtAccessTokenClaims
decodeJwtAccessTokenClaims =
    Decode.succeed JwtAccessTokenClaims
        |> required "is_admin" bool
        |> required "is_active" bool
        |> required "exp" posixFromInt
        |> required "iat" posixFromInt
        |> required "sub" string


defaultJwtAccessTokenClaims : JwtAccessTokenClaims
defaultJwtAccessTokenClaims =
    JwtAccessTokenClaims False False (Time.millisToPosix 0) (Time.millisToPosix 0) ""


{-| posixFromInt converts the incoming time (formatted as epoch in seconds)
to Elm's Time.Posix format
-}
posixFromInt : Decoder Time.Posix
posixFromInt =
    int |> Decode.map (\time -> Time.millisToPosix <| time * 1000)


{-| extractJwtClaims attempts to extract the token claims from the access token
-}
extractJwtClaims : JwtAccessToken -> JwtAccessTokenClaims
extractJwtClaims token =
    let
        jwtParts : List String
        jwtParts =
            String.split "." token

        jwtPayload : String
        jwtPayload =
            case jwtParts of
                _ :: payload :: _ ->
                    Util.base64Decode payload

                _ ->
                    ""
    in
    case Decode.decodeString decodeJwtAccessTokenClaims jwtPayload of
        Ok p ->
            p

        Err _ ->
            defaultJwtAccessTokenClaims
