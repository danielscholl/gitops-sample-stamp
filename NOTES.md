# Access Notes

To access Kiali dashboard:

Run the following commands and visit [http://localhost:20001](http://localhost:20001) in your preferred web browser.

```bash
# Get a Token
kubectl -n istio-system create token kiali-service-account

# Access the UI
kubectl port-forward svc/kiali 20001:20001 -n istio-system
```

To access PodInfo

Run the following commands and visit [http://localhost:20001](http://localhost:20001) in your preferred web browser.

```bash
# Access the UI
kubectl port-forward svc/podinfo 9898:9898 -n sample-app
```
