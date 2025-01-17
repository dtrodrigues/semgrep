#! /usr/bin/env python3
#
# Main function is in run-benchmarks. Can be called via
#               ./run-benchmarks --semgrep_core
#
# Run semgrep-core on a series of pairs (rules, repo) with different options
# and report the time it takes.
#
# semgrep-core needs the user to pass in the language to analyze in.
# We implement that by adding the main language of the rules being run to
# each corpus. However, this limits the set of corpuses we can use.
#
# Right now, the corpus is labelled with a language because we chose to only
# use corpuses that are primarily one language, which makes their runtime
# comparable to the runs using semgrep. We could also have chosen to
# label the rules, or change the pair to (rules, repo, lang), but ultimately
# we would like semgrep-core to be able to infer the language
#
# We are additionally limited by what semgrep-core is able to parse, as
# noted by some commented out tests
#
# The end goal is for semgrep-core to replace semgrep in analyzing rules
# and to unify the two files. The --semgrep_core option is currently meant
# for local convenience, not use in CI
#
# Requires semgrep-core (make install in the semgrep-core folder)
#
import os
import subprocess
import time
import urllib.request
from contextlib import contextmanager
from typing import Iterator

DASHBOARD_URL = "https://dashboard.semgrep.dev"

# Run command and propagate errors
def cmd(*args: str) -> None:
    subprocess.run(args, check=True)  # nosem


class Corpus:
    def __init__(self, name: str, rule_dir: str, target_dir: str, language: str):
        # name for the input corpus (rules and targets)
        self.name = name

        # folder containing the semgrep rules
        self.rule_dir = rule_dir

        # folder containing the target source files
        self.target_dir = target_dir

        # language to run rules with (because semgrep-core requires it)
        self.language = language

    # Fetch rules and targets is delegated to an ad-hoc script named 'prep'.
    def prep(self) -> None:
        cmd("./prep")


CORPUSES = [
    # Run Ajin's nodejsscan rules on some repo containing javascript files.
    # This takes something like 4 hours or more. Maybe we could run it
    # on fewer targets.
    # Corpus("njs", "input/njsscan/njsscan/rules/semantic_grep", "input/juice-shop"),
    Corpus("big-js", "input/semgrep.yml", "input/big-js", "js"),
    # Commented out because it can't run with semgrep-core
    # Corpus(
    #    "njsbox", "input/njsscan/njsscan/rules/semantic_grep", "input/dropbox-sdk-js", "js"
    # ),
    Corpus("zulip", "input/semgrep.yml", "input/zulip", "python"),
    # The tests below all run r2c rulepacks (in r2c-rules) on public repos
    # For command Corpus("$X", ..., "input/$Y"), you can find the repo by
    # going to github.com/$X/$Y
    #
    # Run our django rulepack on a large python repo
    Corpus("apache", "input/django.yml", "input/libcloud", "python"),
    # Run our flask rulepack on a python repo
    Corpus("dropbox", "input/flask.yml", "input/pytest-flakefinder", "python"),
    # Run our golang rulepack on a go/html repo
    Corpus("0c34", "input/golang.yml", "input/govwa", "go"),
    # Run our ruby rulepack on a large ruby repo
    Corpus("rails", "input/ruby.yml", "input/rails", "ruby"),
    # Also commented out because it can't run with semgrep-core
    # Run our javascript and eslint-plugin-security packs on a large JS repo
    # Corpus("lodash", "input/rules", "input/lodash", "js"),
]

DUMMY_CORPUSES = [Corpus("dummy", "input/dummy/rules", "input/dummy/targets", "js")]


class SemgrepVariant:
    def __init__(self, name: str, semgrep_core_extra: str):
        # name for the input corpus (rules and targets)
        self.name = name

        # space-separated extra arguments to pass to the default semgrep
        # command
        self.semgrep_core_extra = semgrep_core_extra


# Semgrep-core variants are separate for now because semgrep-core with
# -config is not official. Still uses the class SemgrepVariant
SEMGREP_CORE_VARIANTS = [
    SemgrepVariant("std", ""),
    SemgrepVariant("no-bloom", "-no_bloom_filter"),
    SemgrepVariant("filter-irrelevant-rules", "-filter_irrelevant_rules"),
    SemgrepVariant(
        "filter-rules_no-bloom", "-filter_irrelevant_rules -no_bloom_filter"
    ),
]

# Add support for: with chdir(DIR): ...
@contextmanager
def chdir(dir: str) -> Iterator[None]:
    old_dir = os.getcwd()
    os.chdir(dir)
    try:
        yield
    finally:
        os.chdir(old_dir)


def upload_result(metric_name: str, value: float) -> None:
    url = f"{DASHBOARD_URL}/api/metric/{metric_name}"
    print(f"Uploading to {url}")
    r = urllib.request.urlopen(  # nosem
        url=url,
        data=str(value).encode("ascii"),
    )
    print(r.read().decode())


def run_semgrep_core(corpus: Corpus, variant: SemgrepVariant) -> float:
    args = []
    common_args = ["-timeout", "0"]
    # Using absolute paths because run_semgrep did, and because it is convenient
    # to be able to run the command in different folders
    args = [
        "semgrep-core",
        "-j",
        "8",
        "-lang",
        corpus.language,
        "-config",
        os.path.abspath(corpus.rule_dir),
        os.path.abspath(corpus.target_dir),
    ]
    args.extend(common_args)
    if variant.semgrep_core_extra != "":
        args.extend(variant.semgrep_core_extra.split(" "))

    print(f"current directory: {os.getcwd()}")
    print("semgrep-core command: {}".format(" ".join(args)))

    t1 = time.time()
    res = subprocess.run(args)  # nosem
    t2 = time.time()

    status = res.returncode
    print(f"semgrep-core exit status: {status}")
    if status == 0:
        print("success")
    elif status == 3:
        print("warning: some files couldn't be parsed")
    else:
        res.check_returncode()

    return t2 - t1


def run_benchmarks(dummy: bool, upload: bool) -> None:
    results = []
    corpuses = CORPUSES
    if dummy:
        corpuses = DUMMY_CORPUSES
    for corpus in corpuses:
        with chdir(corpus.name):
            corpus.prep()
            for variant in SEMGREP_CORE_VARIANTS:
                name = ".".join(["semgrep-core", "bench", corpus.name, variant.name])
                metric_name = ".".join([name, "duration"])
                print(f"------ {name} ------")
                duration = run_semgrep_core(corpus, variant)
                msg = f"{metric_name} = {duration:.3f} s"
                print(msg)
                results.append(msg)
                if upload:
                    upload_result(metric_name, duration)
    for msg in results:
        print(msg)
