# Static media storage

The existing `/containers/mediaserver` filesystem is exposed as the retained
`media` PersistentVolume and claim. Applications that need hardlinks should
mount the whole claim so the `media/`, `scripts/`, and `torrents/` directories
remain on one filesystem.
