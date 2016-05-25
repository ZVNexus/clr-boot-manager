/*
 * This file is part of clr-boot-manager.
 *
 * Copyright (C) 2016 Intel Corporation
 *
 * clr-boot-manager is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1
 * of the License, or (at your option) any later version.
 */

#define _GNU_SOURCE
#include <check.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>

#include "util.h"

#include "files.c"

START_TEST(bootman_hash_test)
{
        const char *known_sha = "4244d61c4e16e14fd7dc8e4836ca45be98122cb2";
        const char *path = TOP_DIR "/tests/data/hashfile";
        char *sha = get_sha1sum(path);

        fail_if(!streq(known_sha, sha), "Computed SHA-1 does not match expectation");
        free(sha);
        sha = NULL;

        sha = get_sha1sum("PATHTHATWONT@EXIST!");
        fail_if(sha, "Got SHA-1 for non-existent path");
}
END_TEST

START_TEST(bootman_uuid_test)
{
        if (geteuid() != 0) {
                LOG("Skipping UUID test as root privileges are required\n");
                return;
        }
        const char *path = TOP_DIR "/tests/data/hashfile";
        autofree(char) *puuid = NULL;

        puuid = get_part_uuid(path);
        fail_if(!puuid, "Failed to get filesystem UUID");

        LOG("PUUID: %s\n", puuid);
}
END_TEST

START_TEST(bootman_find_boot)
{
        if (!cbm_file_exists("/sys/firmware/efi")) {
                LOG("Skipping UEFI host-specific test\n");
                return;
        }
        autofree(char) *boot = NULL;

        boot = get_boot_device();
        fail_if(!boot, "Unable to determine a boot device");
}
END_TEST

START_TEST(bootman_mount_test)
{
        fail_if(!cbm_is_mounted("/", NULL), "Apparently / not mounted. Question physics.");
        fail_if(cbm_is_mounted("/,^roflcopter", NULL), "Non-existent path mounted. Or you have a genuinely weird path");
}
END_TEST

static Suite *core_suite(void)
{
        Suite *s = NULL;
        TCase *tc = NULL;

        s = suite_create("bootman_files");
        tc = tcase_create("bootman_files");
        tcase_add_test(tc, bootman_hash_test);
        tcase_add_test(tc, bootman_uuid_test);
        tcase_add_test(tc, bootman_mount_test);
        tcase_add_test(tc, bootman_find_boot);
        suite_add_tcase(s, tc);

        return s;
}

int main(void)
{
        Suite *s;
        SRunner *sr;
        int fail;

        s = core_suite();
        sr = srunner_create(s);
        srunner_run_all(sr, CK_VERBOSE);
        fail = srunner_ntests_failed(sr);
        srunner_free(sr);

        if (fail > 0) {
                return EXIT_FAILURE;
        }

        return EXIT_SUCCESS;
}

/*
 * Editor modelines  -  https://www.wireshark.org/tools/modelines.html
 *
 * Local variables:
 * c-basic-offset: 8
 * tab-width: 8
 * indent-tabs-mode: nil
 * End:
 *
 * vi: set shiftwidth=8 tabstop=8 expandtab:
 * :indentSize=8:tabSize=8:noTabs=true:
 */