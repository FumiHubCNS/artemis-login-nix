# artemis-login-nix

ARTEMIS のワーキングディレクトリを作成・選択し、対応する `flake.nix` の開発環境へ入るためのログインツールです。

`artlogin` は以下の処理を行います。

- ワークグループごとの設定ファイルを読み込む
- `ART_ANALYSIS_DIR/user/<username>` をワークディレクトリとして使用する
- ワークディレクトリが存在しない場合は Git リポジトリを clone する
- `rawdata` や `output` のシンボリックリンクを必要に応じて作成する
- ワークディレクトリ内の `flake.nix` を確認する
- 最後に `nix develop` を実行して ARTEMIS 開発環境へ入る


設定ファイルは以下の順に検索されます。

```text
1. $ARTLOGIN_CONFIG_DIR/<group>.conf
2. ${XDG_CONFIG_HOME:-$HOME/.config}/artemis-login/<group>.conf
3. artemis-login-nix/env/<group>.conf
```

## 1. Git clone して直接使う

```bash
git clone https://github.com/FumiHubCNS/artemis-login-nix.git
cd artemis-login-nix
chmod +x bin/artlogin-nix
```

envなどに設定ファイルを編集します。

例えば、以下のような`tutorial.conf`を作ります。

```bash
ART_ANALYSIS_DIR="$./tutorial"

ART_DATA_DIR=""
ART_OUTPUT_DIR=""

REPO_TYPE="github"
REPO_PROTOCOL="https"

REPO_OWNER="FumiHubCNS"
REPO_NAME="artemis-workdir-training"

REPO_BRANCH=""
```

設定ファイル名が実行時の第一引数として指定することで読み込めます。

```bash
./bin/artlogin-nix tutorial hoge
```

このように実行すると`$ART_ANALYSIS_DIR/user/hoge`へリポジトリが clone されます。

すでに存在する場合は、そのディレクトリをそのまま使用します。

最後にワークディレクトリへ移動し、`nix develop`にて環境に入ることができます。


## Home Manager 経由で使う

Home Manager を使用している場合は、`artemis-login-nix` を flake input として追加できます。

### flake.nix

`inputs` に `artemis-login-nix` を追加します。

```nix
{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    artemis-login-nix = {
      url = "github:FumiHubCNS/artemis-login-nix";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      artemis-login-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."fendo" =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          modules = [
            ./home.nix
          ];

          extraSpecialArgs = {
            inherit artemis-login-nix;
          };
        };
    };
}
```

`flake = false;` とすることで、`artemis-login-nix` を Nix package としてではなく、ソースツリーとして利用します。

### home.nix

`artemis-login` モジュールを import します。

```nix
{
  imports = [
    ./artemis-login
  ];
}
```


### artemis-login/default.nix

`bin/artlogin-nix` を `artlogin` というコマンド名で利用できるようにします。

```nix
{
  pkgs,
  artemis-login-nix,
  ...
}:

{
  home.packages = [
    (pkgs.writeShellScriptBin "artlogin" ''
      exec ${pkgs.bash}/bin/bash \
        ${artemis-login-nix}/bin/artlogin-nix "$@"
    '')
  ];
}
```


### 設定ファイル

Home Manager 経由では、`artemis-login-nix` 本体は `/nix/store` に配置されます。

そのため設定ファイルは下記に置けるようになっています。

```text
~/.config/artemis-login/
```

## その他

### 別の設定ディレクトリを使う

`ARTLOGIN_CONFIG_DIR` を指定すると、任意のディレクトリを最優先で使用できます。

```bash
export ARTLOGIN_CONFIG_DIR="$HOME/private/artemis-login"
```

例えば、

```text
$HOME/private/artemis-login/tutorial.conf
```

が存在すれば、

```bash
artlogin tutorial fendo
```

でその設定が使用されます。


## 設定ファイルの例

### Public repository + HTTPS

```bash
ART_ANALYSIS_DIR="$./tutorial"

ART_DATA_DIR=""
ART_OUTPUT_DIR=""

REPO_TYPE="github"
REPO_PROTOCOL="https"

REPO_OWNER="FumiHubCNS"
REPO_NAME="artemis-workdir-training"

REPO_BRANCH=""
```

### Private repository + SSH

```bash
ART_ANALYSIS_DIR="./tutorial"

ART_DATA_DIR=""
ART_OUTPUT_DIR=""

REPO_TYPE="github"
REPO_PROTOCOL="ssh"

REPO_OWNER="FumiHubCNS"
REPO_NAME="artemis-workdir-hoge"

REPO_BRANCH="training"

SSH_HOST="github.com"
```

`SSH_HOST`にはAliasも使えます。

### 変数の説明

`ART_DATA_DIR` / `ART_OUTPUT_DIR`は生データや生成ファイルのシンボリックリンク用の変数です。

空文字の場合はリンクを生成しません。

データディレクトリを指定した場合、

```bash
ART_DATA_DIR="/path/to/data"
```

ワークディレクトリ内に、

```text
rawdata -> /path/to/data
```

が作成されます。

出力ディレクトリを指定した場合、

```text
output -> /path/to/output
```

が作成されます。

`ART_ANALYSIS_DIR`は解析ディレクトリのパスを指定します。

指定したパスが存在しない場合は、自動的に作成されます。

例えば、

```bash
ART_ANALYSIS_DIR="./tutorial"
```

を指定した場合、実行した場所から`tutorial/user/[user_name]`に生成されます。
