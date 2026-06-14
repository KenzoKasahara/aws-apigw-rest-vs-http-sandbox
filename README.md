# aws-apigw-rest-vs-http-sandbox

AWS API Gateway の REST API (v1) と HTTP API (v2) をレイテンシと CloudWatch メトリクス仕様の観点で比較するための PoC リポジトリ。

## このリポジトリで行うこと

AWS API Gateway の **REST API (v1)** と **HTTP API (v2)** を同一の Lambda バックエンドに接続し、以下の 2 点を実測・比較する PoC。

1. **レイテンシ差の検証** — `curl` による繰り返しリクエストと CloudWatch の `Latency` / `IntegrationLatency` メトリクスを用いて、ゲートウェイオーバーヘッド（Latency − IntegrationLatency）が REST > HTTP になることを確認する。

2. **CloudWatch メトリクス仕様差の把握** — メトリクス名・ディメンションキーが REST と HTTP で異なる（例: `4XXError` vs `4xx`、ディメンション `ApiName` vs `ApiId`）ため、REST → HTTP 移行時に既存アラームが無効化される落とし穴を再現し、移行時の注意点を整理する。

## アーキテクチャ

構成図: ![docs/architecture.drawio](docs/architecture.png)

<!-- draw.io ファイルを GitHub / VS Code の draw.io 拡張で開いて確認してください -->

## リソース作成手順

### 前提条件

- Terraform >= 1.10
- AWS CLI が設定済みであること（`aws configure` または環境変数）

### 1. 変数ファイルの準備

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

`terraform/terraform.tfvars` を編集して以下の変数を設定する。

| 変数名 | 型 | 説明 | サンプル値 |
| --- | --- | --- | --- |
| `aws_region` | `string` | リソースをデプロイする AWS リージョン | `ap-northeast-1` |
| `project_name` | `string` | リソース名・タグのプレフィックス | `apigw-compare` |

### 2. 初期化

```bash
cd terraform
terraform init
```

### 3. 実行計画の確認

```bash
terraform plan
```

### 4. リソースの作成

```bash
terraform apply
```

適用後、以下の出力値が表示される。

| 出力名 | 説明 |
| --- | --- |
| `rest_api_url` | REST API (v1) のエンドポイント URL（レイテンシ計測用） |
| `http_api_url` | HTTP API (v2) のエンドポイント URL（レイテンシ計測用） |

### 5. レイテンシ計測

`terraform output` でエンドポイント URL を取得し、`curl` で比較計測する。

```bash
REST_URL=$(terraform output -raw rest_api_url)
HTTP_URL=$(terraform output -raw http_api_url)

# 各 API を 10 回リクエストして応答時間を記録
for i in $(seq 10); do curl -o /dev/null -s -w "%{time_total}\n" "$REST_URL"; done
for i in $(seq 10); do curl -o /dev/null -s -w "%{time_total}\n" "$HTTP_URL"; done
```

CloudWatch コンソールで `Latency` と `IntegrationLatency` を並べて確認し、差分（＝ゲートウェイオーバーヘッド）が REST > HTTP になることを検証する。

| CloudWatch メトリクス | REST API | HTTP API |
| --- | --- | --- |
| クライアントエラー | `4XXError` | `4xx` |
| サーバーエラー | `5XXError` | `5xx` |
| 主ディメンション | `ApiName` | `ApiId` |

> REST → HTTP 移行時にアラームが無反応になる典型的な落とし穴。既存のアラームはそのまま流用不可。

### 6. リソースの削除

```bash
terraform destroy
```

## 計測結果

### curl レイテンシ（クライアント側 RTT 込み）

各エンドポイントに 10 回リクエストを送信した結果（単位: 秒）。

| | 1 回目（コールドスタート） | 2〜10 回目 平均 | 2〜10 回目 最小 | 2〜10 回目 最大 |
| --- | ---: | ---: | ---: | ---: |
| **REST API** | 424.6 ms | 62.5 ms | 50.3 ms | 79.9 ms |
| **HTTP API** | 175.0 ms | 63.3 ms | 46.5 ms | 99.9 ms |

#### REST API（生データ）

```text
0.424647
0.073436
0.057704
0.055697
0.079914
0.055408
0.053593
0.078805
0.050286
0.058012
```

#### HTTP API（生データ）

```text
0.174987
0.065422
0.059369
0.056784
0.099951
0.058270
0.060078
0.055493
0.067879
0.046549
```

#### CloudWatch メトリクス比較

単位: ms。`GW overhead = Latency − IntegrationLatency`（ゲートウェイ自身の処理時間）。

| API タイプ | Latency | IntegrationLatency | GW overhead |
| --- | ---: | ---: | ---: |
| HTTP API | 18.6 ms | 13.6 ms | 5.0 ms |
| REST API | 56.2 ms | 52.9 ms | 3.3 ms |

![apigateway-http](/docs/images/apigateway-http.png)
![apigateway-rest](/docs/images/apigateway-rest.png)

### 考察

- **コールドスタート時（curl 1 回目）** は REST API が約 2.4 倍遅い（424.6 ms vs 175.0 ms）。Lambda のコールドスタートに加え、REST API の多段パイプライン初期化コストが重なっている。
- **ウォームリクエスト時（curl 2〜10 回目）** は両者がほぼ同等（約 63 ms）。クライアント〜リージョン間の RTT がボトルネックになっており、ゲートウェイオーバーヘッドの差が吸収されている。
- **CloudWatch メトリクスで見た全体レイテンシ** は REST API が約 3 倍大きい（56.2 ms vs 18.6 ms）。ただし差の主因は IntegrationLatency（Lambda 処理時間）であり、REST 計測時に Lambda がコールドスタートしていた可能性が高い。
- **GW overhead 単体** は今回の計測では REST (3.3 ms) vs HTTP (5.0 ms) と逆転しており、サンプル数が少ないため断定できない。ゲートウェイオーバーヘッドの差を定量化するには、Lambda をウォームアップした状態でのサンプル数増加が必要。
