import { CoverType, ViewMetaCover } from '@/application/types';
import React, { useMemo } from 'react';
import { PopoverOrigin, PopoverProps } from '@mui/material/Popover';
import { EmbedLink, Unsplash, UploadTabs, TabOption, TAB_KEY, UploadImage } from '@/components/_shared/image-upload';
import { useTranslation } from 'react-i18next';
import Colors from './CoverColors';

const initialOrigin: {
  anchorOrigin: PopoverOrigin;
  transformOrigin: PopoverOrigin;
} = {
  anchorOrigin: {
    vertical: 'bottom',
    horizontal: 'center',
  },
  transformOrigin: {
    vertical: -20,
    horizontal: 'center',
  },
};

function CoverPopover ({
  anchorPosition,
  open,
  onClose,
  onUpdateCover,
}: {
  anchorPosition?: PopoverProps['anchorPosition'];
  open: boolean;
  onClose: () => void;
  onUpdateCover?: (cover: ViewMetaCover) => void;
}) {
  const { t } = useTranslation();
  const tabOptions: TabOption[] = useMemo(() => {
    return [
      {
        label: t('document.plugins.cover.colors'),
        key: TAB_KEY.Colors,
        Component: Colors,
        onDone: (value: string) => {
          onUpdateCover?.({
            type: CoverType.NormalColor,
            value,
          });
        },
      },
      {
        label: t('button.upload'),
        key: TAB_KEY.UPLOAD,
        Component: UploadImage,
        onDone: (value: string) => {
          onUpdateCover?.({
            type: CoverType.CustomImage,
            value,
          });
          onClose();
        },
      },
      {
        label: t('document.imageBlock.embedLink.label'),
        key: TAB_KEY.EMBED_LINK,
        Component: EmbedLink,
        onDone: (value: string) => {
          onUpdateCover?.({
            type: CoverType.CustomImage,
            value,
          });
          onClose();
        },
      },
      {
        key: TAB_KEY.UNSPLASH,
        label: t('document.imageBlock.unsplash.label'),
        Component: Unsplash,
        onDone: (value: string) => {
          onUpdateCover?.({
            type: CoverType.UpsplashImage,
            value,
          });
        },
      },
    ];
  }, [onClose, onUpdateCover, t]);

  return (
    <UploadTabs
      popoverProps={{
        anchorPosition,
        open,
        onClose,
        ...initialOrigin,
        anchorReference: 'anchorPosition',
      }}
      containerStyle={{ width: 433, maxHeight: 500 }}
      tabOptions={tabOptions}
    />
  );
}

export default CoverPopover;